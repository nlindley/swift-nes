"use strict";

const Hapi = require("@hapi/hapi");
const Nes = require("@hapi/nes");

const init = async () => {
  const server = Hapi.server({
    port: 3000,
    host: "0.0.0.0",
  });

  await server.register(Nes);

  server.subscription("/counter/{count}", {
    onSubscribe: async (socket, path, params) => {
      let messagesSent = 0;
      const count = Number.parseInt(params.count, 10);
      console.log("Subscriber", socket.id, path, params);
      const timeout = setInterval(async () => {
        if (messagesSent === count) {
          clearInterval(timeout);
          console.log("done sending messages");
          await socket.revoke(path, { message: "all messages sent" });
        } else {
          messagesSent += 1;
          console.log("sending message", messagesSent);
          await socket.publish(path, { count: messagesSent });
        }
      }, 10);
    },
  });

  await server.start();
  console.log("Server running on %s", server.info.uri);

  const shutdown = async () => {
    console.log("Stopping");
    await server.stop();
    process.exit(0);
  };

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
};

process.on("unhandledRejection", (err) => {
  console.log(err);
  process.exit(1);
});

init();
