import Animation exposing (Animation, animate, animation, duration, from, to, ease)
import AnimationFrame
import Char
import Collage exposing (Form, collage, circle, filled, move, moveY, text, rotate)
import Color exposing (rgba)
import Dict exposing (Dict, fromList, values)
import Ease
import Element
import Html exposing (Html, div)
import Html.Attributes exposing (style)
import Html.App exposing (program)
import Keyboard exposing (KeyCode)
import List exposing (length, map)
import Mouse
import String exposing (split)
import Task exposing (perform)
import Text
import Time exposing (Time)
import WebSocket
import Window

socketUrl = "wss://emoji-dance.boilerroom.tv/dancers"

main =
  program
    { init = init
    , subscriptions = subscriptions
    , update = update
    , view = view
    }

--
-- Domain
--

type alias DancerId = String
type alias Position = (Float, Float)
type alias Size = (Int, Int)
type alias DanceMove = Position
type alias Mood = Int

type alias Dancer =
  { position : Position
  , mood : Mood
  }

type alias Fire =
  { position : Position
  , start : Time
  }

type alias Model =
  { bounces : Dict DancerId Animation
  , dancers : Dict DancerId Dancer
  , fires : List Fire -- ordered by time.
  , myId : DancerId
  , me : Dancer
  , now : Time
  , spins : Dict DancerId Animation
  , windowSize : Size
  }

model : Model
model =
  { bounces = Dict.empty
  , dancers = Dict.empty
  , fires = []
  , myId = ""
  , me = { position = (0.5, 0.5), mood = defaultMood }
  , now = 0
  , spins = Dict.empty
  , windowSize = (0, 0)
  }

type Msg
  = DoNothing
  | Click Mouse.Position
  | MoveMouse Mouse.Position
  | PressKey KeyCode
  | ResizeWindow Window.Size
  | ReceiveRemoteMessage String
  | Tick Time

init : (Model, Cmd Msg)
init =
  (model, perform (\_ -> DoNothing) ResizeWindow Window.size)

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
    [ AnimationFrame.times Tick
    , Keyboard.downs PressKey
    , Mouse.clicks Click
    , Mouse.moves MoveMouse
    , Window.resizes ResizeWindow
    , WebSocket.listen socketUrl ReceiveRemoteMessage
    ]

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  -- Debug.log (toString msg) <|
  case msg of
    DoNothing ->
      (model, Cmd.none)
    Click _ ->
      ({ model | bounces = Dict.insert model.myId (bounce model.now) model.bounces }, sendMessage SendBounce)
    MoveMouse { x, y } ->
      let
        position = normalized model.windowSize (toFloat x, toFloat y)
        me = model.me
      in
        ({ model | me = { me | position = position } }, sendMessage (SendMove position))
    PressKey keyCode ->
      handleKeyPress model keyCode
    ResizeWindow { width, height } ->
      ({ model | windowSize = (width, height) }, Cmd.none)
    ReceiveRemoteMessage remoteMessage ->
      handleRemoteMessage model <| parseRemoteMessage remoteMessage
    Tick t ->
      let
        fires = case model.fires of
          [] -> []
          { position, start } :: laterFires ->
            if start + 1000 < t
              then laterFires
              else model.fires
      in
        ({ model | now = t, fires = fires }, Cmd.none)

newFire : Model -> Position -> Model
newFire model position =
  { model | fires = model.fires ++ [{ position = position, start = model.now }] }

newSpin : Model -> DancerId -> Model
newSpin model dancerId =
  { model | spins = Dict.insert dancerId (spin model.now) model.spins }

--
-- View
--

view : Model -> Html Msg
view model =
  let (width, height) = model.windowSize in
    div
      [ style [ ("backgroundColor", "black") ] ]
      [ Element.toHtml <| collage width height <| dancers model ++ fires model ]

dancers : Model -> List Form
dancers model =
  let
    dancerAngle dancerId = case Dict.get dancerId model.spins of
      Just spin -> animate model.now spin
      Nothing -> 0
    dancerSize dancerId = 50 + case Dict.get dancerId model.bounces of
      Just bounce -> animate model.now bounce
      Nothing -> 0
    dancer dancerId { position, mood } =
      move (screen model.windowSize position) <|
      rotate (turns <| dancerAngle dancerId) <|
      text <| Text.height (dancerSize dancerId) <| Text.fromString <| emoji mood
    me = dancer model.myId model.me
    others = values <| Dict.map dancer model.dancers
  in
    others ++ [ me ]

emoji : Mood -> String
emoji mood =
  case mood of
    0 -> "😡"
    1 -> "😲"
    2 -> "😳"
    3 -> "😐"
    4 -> "🙂"
    5 -> "😋"
    6 -> "😍"
    _ -> "👁"

fires : Model -> List Form
fires model =
  let
    fire { position, start } =
      moveY ((model.now - start) / 10) <|
      move (screen model.windowSize position) <|
      text <| Text.height 50 <| Text.fromString "🔥"
  in
    map fire model.fires

normalized : Size -> Position -> Position
normalized (width, height) (x, y) =
  (x / toFloat width, y / toFloat height)

screen : Size -> Position -> Position
screen (width, height) (x, y) =
  (x * toFloat width - (toFloat width / 2), (toFloat height / 2) - y * toFloat height)

--
-- Animations
--

bounce : Time -> Animation
bounce time =
  animation time |>
  duration 200 |>
  from 10 |>
  to 0 |>
  ease Ease.inBack

spin : Time -> Animation
spin time =
  animation time |>
  duration 500 |>
  from 0 |>
  to 1 |>
  ease Ease.outCubic

--
-- Incoming messages
--

type InMessage
  = ReceiveBounce String
  | ReceiveJoin String
  | ReceiveFire String
  | ReceiveMood String String
  | ReceiveMove String String
  | ReceiveLeave String
  | ReceiveSpin String

parseRemoteMessage : String -> Maybe InMessage
parseRemoteMessage message =
  let parsedMessage = split ":" message in
    case parsedMessage of
      [dancerId, "b"] -> Just <| ReceiveBounce dancerId
      [dancerId, "e", mood] -> Just <| ReceiveMood dancerId mood
      [_, "f", position] -> Just <| ReceiveFire position
      [dancerId, "join"] -> Just <| ReceiveJoin dancerId
      [dancerId, "leave"] -> Just <| ReceiveLeave dancerId
      [dancerId, "m", move] -> Just <| ReceiveMove dancerId move
      [dancerId, "s"] -> Just <| ReceiveSpin dancerId
      _ -> Nothing

handleRemoteMessage : Model -> Maybe InMessage -> (Model, Cmd Msg)
handleRemoteMessage model maybeMessage =
  case maybeMessage of
    Nothing -> update DoNothing model
    Just message -> handleRemoteMessage' model message

handleRemoteMessage' : Model -> InMessage -> (Model, Cmd Msg)
handleRemoteMessage' model message =
  let
    withPosition positionString handler = case parsePosition positionString of
      Just position -> handler position
      Nothing -> update DoNothing model
    withMood maybeMood handler = case parseMood maybeMood of
      Just mood -> handler mood
      Nothing -> update DoNothing model
    moveDancer position maybeDancer =
      case maybeDancer of
        Just dancer -> Just { dancer | position = position }
        Nothing -> Just { position = position, mood = defaultMood } -- Create a new dancer.
  in
    case message of
      ReceiveBounce dancerId ->
        ({ model | bounces = Dict.insert dancerId (bounce model.now) model.bounces }, Cmd.none)
      ReceiveJoin dancerId ->
        ({ model | myId = dancerId }, Cmd.none)
      ReceiveFire pos -> withPosition pos <| \position ->
        (newFire model position, Cmd.none)
      ReceiveLeave dancerId ->
        ({ model | dancers = Dict.remove dancerId model.dancers }, Cmd.none)
      ReceiveMood dancerId maybeMood -> withMood maybeMood <| \mood ->
        ({ model | dancers = Dict.update dancerId (Maybe.map (\dancer -> { dancer | mood = mood })) model.dancers }, Cmd.none)
      ReceiveMove dancerId move -> withPosition move <| \position ->
        ({ model | dancers = Dict.update dancerId (moveDancer position) model.dancers }, Cmd.none)
      ReceiveSpin dancerId ->
        (newSpin model dancerId, Cmd.none)

parsePosition : String -> Maybe Position
parsePosition position =
  let parsedPosition = split "," position in
    case parsedPosition of
      [x, y] ->
        Result.toMaybe <| Result.map2
          (\x' y' -> (x', y'))
          (String.toFloat x)
          (String.toFloat y)
      _ ->
        Nothing

parseMood : String -> Maybe Mood
parseMood moodString =
  case String.toInt moodString of
    Ok moodInt -> if moodInt >= 0 && moodInt <= maxMood then Just moodInt else Nothing
    Err _ -> Nothing

--
-- Outgoing messages
--

type OutMessage
  = SendBounce
  | SendFire Position
  | SendMood Mood
  | SendMove DanceMove
  | SendSpin

handleKeyPress : Model -> KeyCode -> (Model, Cmd Msg)
handleKeyPress model keyCode =
  -- case Debug.log "key code" keyCode of
  case keyCode of
    70 {- f -} -> (newFire model model.me.position, sendMessage (SendFire model.me.position))
    83 {- s -} -> (newSpin model model.myId, sendMessage SendSpin)
    38 {- up -} -> let newMe = increaseMood model.me in
      ({ model | me = newMe }, if newMe.mood /= model.me.mood then sendMessage (SendMood newMe.mood) else Cmd.none)
    40 {- down -} -> let newMe = decreaseMood model.me in
      ({ model | me = newMe }, if newMe.mood /= model.me.mood then sendMessage (SendMood newMe.mood) else Cmd.none)
    _ -> update DoNothing model

serializeMessage : OutMessage -> String
serializeMessage message =
  let serializeCommand command arguments = String.join ":" [command, arguments] in
    case message of
      SendBounce -> "b"
      SendFire (x, y) -> serializeCommand "f" <| toString x ++ "," ++ toString y
      SendMood mood -> serializeCommand "e" <| toString mood
      SendMove (x, y) -> serializeCommand "m" <| toString x ++ "," ++ toString y
      SendSpin -> "s"

sendMessage : OutMessage -> Cmd Msg
sendMessage message =
  WebSocket.send socketUrl <| serializeMessage message

--
-- Mood
--

defaultMood = 3
minMood = 0
maxMood = 6

increaseMood : Dancer -> Dancer
increaseMood dancer =
  { dancer | mood = min (dancer.mood + 1) maxMood }

decreaseMood : Dancer -> Dancer
decreaseMood dancer =
  { dancer | mood = max (dancer.mood - 1) minMood }
