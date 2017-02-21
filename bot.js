const WebSocket = require('ws')

const socket = new WebSocket('ws://localhost:1337/dancers')

function constrain (n) {
  if (n < 0) return constrain(-n)
  if (n > 1) return (n % 1)
  return n
}

class SimpleBot {
  constructor () {
    this.x = Math.random()
    this.y = Math.random()
    this.velocity = 0.005
    this.angle = Math.random() * 2 * Math.PI
    this.angleChange = 0.1
  }

  position () {
    this.x = this.x + this.velocity * Math.cos(this.angle)
    this.y = this.y + this.velocity * Math.sin(this.angle)
    this.angle = this.angle + this.angleChange
    return {x: this.x, y: this.y}
  }
}

socket.on('open', () => {
  const bot = new SimpleBot()
  setInterval(() => {
    const {x, y} = bot.position()
    socket.send(`m:${x},${y}`)
  }, 1000 / 60)
})
