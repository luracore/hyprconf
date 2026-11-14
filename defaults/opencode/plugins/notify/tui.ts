import { spawn } from "node:child_process"
import { Plugin } from "@opencode/plugin/tui"

function notify(body: string) {
  spawn("notify-send", ["-a", "OpenCode", "-i", "utilities-terminal", "OpenCode", body], {
    detached: true,
    stdio: "ignore",
  }).unref()
}

export default Plugin.define({
  id: "hyprconf.notify.done",
  setup(context) {
    // session.idle não chega aos plugins do TUI; o fim de turno chega aqui.
    return context.data.on("session.execution.succeeded", (event) => {
      const sessionID = event.data.sessionID

      // Ignora subagentes.
      if (context.data.session.root(sessionID) !== sessionID) return

      notify(context.data.session.get(sessionID)?.title ?? "sessão")
    })
  },
})
