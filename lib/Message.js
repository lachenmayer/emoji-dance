const commands = {
  bounce: 'b',
  join: 'join',
  fire: 'f',
  leave: 'leave',
  mood: 'e',
  move: 'm',
  spin: 's',
}

const maxMood = 6

class Message {
  constructor (command, args) {
    this.command = command
    this.args = args
  }

  serialize () {
    const serializedArgs = this.serializeArgs()
    if (serializedArgs) {
      return this.command + ':' + serializedArgs
    } else {
      return this.command
    }
  }

  serializeArgs () {
    switch (this.command) {
      case commands.mood:
        const mood = this.args
        return `${mood}`
      case commands.fire:
      case commands.move:
        const {x, y} = this.args
        return `${x},${y}`
    }
    return null
  }
}

Message.parse = function (message) {
  const [command, args] = message.split(':', 2)
  switch (command) {
    case commands.bounce: return new Message(commands.bounce)
    case commands.fire: return new Message(commands.fire, parsePosition(args))
    case commands.mood: return new Message(commands.mood, parseMood(args))
    case commands.move: return new Message(commands.move, parsePosition(args))
    case commands.spin: return new Message(commands.spin)
  }
  throw new Error(`invalid message: ${message}`)
}

function parsePosition (position) {
  const [xStr, yStr] = position.split(',', 2)
  const x = Number.parseFloat(xStr)
  const y = Number.parseFloat(yStr)
  if (isNaN(x) || isNaN(y)) {
    throw new Error(`invalid position: ${position}`)
  }
  return {x, y}
}

function parseMood (moodString) {
  const mood = Number.parseInt(moodString)
  if (isNaN(mood) || mood < 0 || mood > maxMood) {
    throw new Error(`invalid mood: ${mood}`)
  }
  return mood
}

module.exports = {commands, Message}
