// fzf do RepoStore: vale na próxima vez que ele abrir.

"use strict";

const path = require("path");

const TARGET = path.resolve(__dirname, "../../../apps/repostore/fzf-current.opts");

function generate(c) {
    // bg -1: o fundo do terminal, que já segue o tema
    return [
        `--color=fg:${c.text},bg:-1,hl:${c.primary},fg+:${c.text},bg+:${c.surface},hl+:${c.primary}`,
        `--color=info:${c.muted},prompt:${c.primary},pointer:${c.primary},marker:${c.green},spinner:${c.primary}`,
        `--color=header:${c.muted},border:${c.outline},separator:${c.outline},scrollbar:${c.outline}`,
        `--color=label:${c.primary},query:${c.text},preview-bg:-1,gutter:-1`,
    ].join("\n") + "\n";
}

module.exports = { target: TARGET, generate };
