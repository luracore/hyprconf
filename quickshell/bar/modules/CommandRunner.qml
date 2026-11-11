import Quickshell.Io
import QtQuick

// Roda comandos e devolve o resultado: run(args, callback(código, stdout, stderr)).
// Os comandos rodam com LC_ALL=C, para a saída não depender do idioma.
Item {
    id: root

    Component {
        id: commandComponent

        Process {
            id: proc

            property var callback: null
            property int exitCode: -1
            property int pending: 3      // stdout, stderr e saída do processo

            function step() {
                pending -= 1;
                if (pending > 0)
                    return;
                if (callback)
                    callback(exitCode, out.text, err.text);
                destroy();
            }

            environment: ({ "LC_ALL": "C" })
            stdout: StdioCollector { id: out; onStreamFinished: proc.step() }
            stderr: StdioCollector { id: err; onStreamFinished: proc.step() }
            onExited: (code, status) => {
                exitCode = code;
                step();
            }
        }
    }

    function run(args, callback) {
        const proc = commandComponent.createObject(root, { command: args, callback: callback ?? null });
        proc.running = true;
    }
}
