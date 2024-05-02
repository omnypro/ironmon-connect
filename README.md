# Ironmon Connect

Ironmon Connect is an extension to the [Ironmon Tracker](https://github.com/besteon/Ironmon-Tracker/tree/main) that allows data about runs to be delivered to an external system via BizHawk's web socket system.

This project was created with the intent of having an overlay system react to different events during a run. For example, upon a Pokemon leaving the lab, the external overlay could update its visuals to reflect that.

**This script only works with FireRed/LeafGreen** at the moment. As there are no official checkpoints or stages of each run, all checkpoints are customized to [my own](https://twitch.tv/avalonstar) runs. Checkpoints for each of the rival battles, the first trainer in Viridian Forest, and the non-gym Giovanni battles are included in addition to the standard gym leaders and Elite Four.

## Installation

BizHawk's socket server functionality is required in order for Ironmon Connect to work. As such, the consuming application must be running before BizHawk is started. The given application can be connected by launching EmuHawk with the following command line arguments:

```shell
EmuHawk.exe --socket_ip=127.0.0.1 --socket_port=8080
```

BizHawk will not launch if it cannot connect to the application.

### Example Node Application

```javascript
import net from 'node:net';

const server = net.createServer((socket) => {
  console.log('client connected');
  
  socket.on('data', (data)=> {
    // `data.toString()` will be 'message_length message'
    // If the message sent is 'pong', `data.toString()` will be '4 pong'.
    // Multiple messages could also be sent at once.
    console.log(data.toString())
  })
   
  socket.on('end', () => {
    console.log('client disconnected');
  });
});

server.on('error', (err) => {
  throw err;
});

server.listen(8080, () => {
  console.log('server bound');
});
```

## Impelementation Notes

The messages sent to the external system are categorized into multiple types:

* `seed` - A new seed has been generated.
* `checkpoint` - A checkpoint has been reached.

## Credits

* UTDZac - For their continued work on the Ironmon tracker.
* Muddr - For writing the pseduo-code that inspired this project.
