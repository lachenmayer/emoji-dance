const ecstatic = require('ecstatic')
const http = require('http')
const through = require('through2')
const {Server} = require('ws')

const Dancer = require('./lib/Dancer')

const port = 1337

const danceFloor = through.obj()
const server = http.createServer(ecstatic({ root: __dirname + '/public' }))
const socketServer = new Server({server})
server.listen(port, () => {
  console.log('up')
})

var nextDancer = 0
var dancers = {}
socketServer.on('connection', socket => {
  var id = nextDancer++
  var dancer = new Dancer(danceFloor, socket, id)
  dancers[id] = dancer
  
  dancer.join(dancers)
  socket.on('message', message => {
    dancer.receiveMessage(message)
  })
  socket.on('close', () => {
    dancer.leave()
    delete dancers[id]
  })
})
