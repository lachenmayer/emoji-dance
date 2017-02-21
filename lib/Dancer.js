const through = require('through2')
const {commands, Message} = require('./Message')

const actions = {
  connect: 'connect',
  disconnect: 'disconnect',
  invalidMessage: 'invalidMessage',
}

const defaultMood = 3

class Dancer {
  constructor (danceFloor /* through pipe */, socket /* ws socket */, id) {
    this.id = id
    this.danceFloor = danceFloor
    this.socket = socket
    const {remoteAddress: ip, remotePort: port} = socket._socket
    this.connection = {id, ip, port}

    this.lastMove = new Message(commands.move, {x: 0.5, y: 0.5})
    this.lastMood = new Message(commands.mood, defaultMood)
  }

  join (dancers = {}) {
    this.log(actions.connect)
    this.sendMessage(this.id, new Message(commands.join))

    // Send the current state of the dancefloor.
    Object.keys(dancers).forEach(dancerId => {
      if (dancerId == this.id) return
      const dancer = dancers[dancerId]
      this.sendMessage(dancerId, dancer.lastMove)
      this.sendMessage(dancerId, dancer.lastMood)
    })

    this.joinDancefloor()
  }

  joinDancefloor () {
    this.danceMoves = through.obj((dancerMessage, encoding, done) => {
      const {dancerId, message} = dancerMessage

      // Don't send me my own moves.
      if (dancerId === this.id) return done()

      this.sendMessage(dancerId, message)
      done()
    })
    this.danceFloor.pipe(this.danceMoves)
  }

  sendMessage /* to dancer */ (dancerId, message) {
    const serializedMessage = message.serialize()
    const dancerMessage = dancerId + ':' + serializedMessage
    this.socket.send(dancerMessage)
  }

  receiveMessage /* from dancer */ (messageString) {
    try {
      const message = Message.parse(messageString)
      this.broadcastMessage(message)
      switch (message.command) {
        case commands.mood: this.lastMood = message; break
        case commands.move: this.lastMove = message; break
      }
    } catch (e) {
      this.log(actions.invalidMessage, {message: messageString})
    }
  }

  broadcastMessage /* to danceFloor */ (message) {
    this.danceFloor.write({dancerId: this.id, message})
  }

  log (action, etc) {
    console.log(JSON.stringify(Object.assign({action}, this.connection, etc)))
  }

  leave () {
    this.danceFloor.unpipe(this.danceMoves)
    this.broadcastMessage(new Message(commands.leave))
    this.log(actions.disconnect)
  }
}

module.exports = Dancer
