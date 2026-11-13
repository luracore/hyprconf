.pragma library

// Completa um tema no formato de Themes/*.json (neutrals + palette + roles)
// numa tabela plana de cores, calculando tudo o que o tema não define.
//
// Fonte única dessas regras: usado pela barra e pelo seletor (Quickshell,
// via symlink nas pastas deles) e pelo Themes/converters/main.js (Node).
//
// Resultado: background, surface, overlay, outline, muted, text,
//            red, orange, yellow, green, cyan, blue, magenta,
//            primary, secondary, tertiary, error, warning, success, info,
//            e on<Nome> (cor de texto legível por cima) para cada cor
//            da paleta e cada papel.

const NEUTRALS = ["background", "surface", "overlay", "outline", "muted", "text"]

// Tema usado para as cores obrigatórias que faltarem (ou se o arquivo falhar).
const FALLBACK = {
    neutrals: {
        background: "#1F1F28",
        text: "#DCD7BA"
    },
    palette: {
        red: "#E82424",
        yellow: "#E6C384",
        green: "#98BB6C",
        cyan: "#7AA89F",
        blue: "#7E9CD8",
        magenta: "#957FB8"
    }
}

const DEFAULT_ROLES = {
    primary: "blue",
    secondary: "magenta",
    tertiary: "cyan",
    error: "red",
    warning: "yellow",
    success: "green",
    info: "cyan"
}

// ---- utilitários de cor -------------------------------------------------

function parseHex(hex) {
    const m = /^#?([0-9a-f]{6})$/i.exec(String(hex).trim())
    if (!m)
        return null
    const n = parseInt(m[1], 16)
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255]
}

function toHex(rgb) {
    return "#" + rgb.map(c => Math.round(Math.min(255, Math.max(0, c)))
        .toString(16).padStart(2, "0")).join("").toUpperCase()
}

// t = 0 -> a, t = 1 -> b
function mix(a, b, t) {
    const x = parseHex(a), y = parseHex(b)
    return toHex(x.map((c, i) => c + (y[i] - c) * t))
}

function luminance(hex) {
    const lin = parseHex(hex).map(c => {
        c /= 255
        return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
    })
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]
}

function contrast(a, b) {
    const la = luminance(a), lb = luminance(b)
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
}

// entre o background e o text do próprio tema, o que for mais legível
function onColor(bg, n) {
    return contrast(bg, n.background) >= contrast(bg, n.text) ? n.background : n.text
}

// ---- resolução ----------------------------------------------------------

function valid(v) {
    return typeof v === "string" && parseHex(v) !== null
}

function pick(section, key, fallback, warn) {
    const v = section[key]
    if (v === undefined)
        return fallback
    if (!valid(v)) {
        warn("cor inválida em " + key + ": " + v)
        return fallback
    }
    return v
}

// theme: objeto do JSON; fallback (opcional): tema completo usado para as
// chaves obrigatórias que faltarem, padrão FALLBACK
function resolve(theme, fallback, warn) {
    warn = warn || function () {}
    theme = theme || {}
    fallback = fallback || FALLBACK

    const tn = theme.neutrals || {}, tp = theme.palette || {}
    const fn = fallback.neutrals, fp = fallback.palette

    // neutros: só background e text são obrigatórios
    const n = {}
    n.background = pick(tn, "background", fn.background, warn)
    n.text = pick(tn, "text", fn.text, warn)
    n.surface = pick(tn, "surface", mix(n.background, n.text, 0.06), warn)
    n.overlay = pick(tn, "overlay", mix(n.surface, n.text, 0.08), warn)
    n.outline = pick(tn, "outline", mix(n.background, n.text, 0.25), warn)
    n.muted = pick(tn, "muted", mix(n.background, n.text, 0.5), warn)

    // paleta: as 6 cores ANSI são obrigatórias, orange é calculado
    const p = {}
    for (const key of ["red", "yellow", "green", "cyan", "blue", "magenta"]) {
        if (tp[key] === undefined)
            warn("paleta sem '" + key + "', usando a do fallback")
        p[key] = pick(tp, key, fp[key], warn)
    }
    p.orange = pick(tp, "orange", mix(p.red, p.yellow, 0.5), warn)

    const out = Object.assign({}, n, p)

    // papéis: nome de uma cor (neutra ou da paleta) ou um hex
    const roles = Object.assign({}, DEFAULT_ROLES, theme.roles || {})
    for (const role in roles) {
        const ref = roles[role]
        if (valid(ref))
            out[role] = ref
        else if (Object.prototype.hasOwnProperty.call(out, ref))
            out[role] = out[ref]
        else {
            warn("papel '" + role + "' aponta para cor desconhecida: " + ref)
            out[role] = out[DEFAULT_ROLES[role]] || p.blue
        }
    }

    // on<Nome> para paleta e papéis (os neutros usam "text" diretamente).
    // Itera sobre uma cópia das chaves: adicionar onX dentro de um for-in
    // sobre o próprio objeto faz o loop visitar onX, onOnX, ... para sempre.
    for (const key of Object.keys(out)) {
        if (NEUTRALS.indexOf(key) >= 0)
            continue
        out["on" + key.charAt(0).toUpperCase() + key.slice(1)] = onColor(out[key], n)
    }

    return out
}

// ---- cor a partir de uma imagem (capa do álbum) ------------------------

function hsv(rgb) {
    const [r, g, b] = rgb.map(c => c / 255)
    const max = Math.max(r, g, b), min = Math.min(r, g, b)
    return { s: max === 0 ? 0 : (max - min) / max, v: max }
}

// clareia/escurece fg em direção a "towards" até ter o contraste pedido com bg
function ensureContrast(fg, bg, ratio, towards) {
    let out = fg
    for (let t = 0.1; contrast(out, bg) < ratio && t <= 1; t += 0.1)
        out = mix(fg, towards, t)
    return out
}

// candidates: lista de hex (ex.: saída do ColorQuantizer)
// theme: Theme.colors (usa surface e text)
// Retorna a cor mais "viva" ajustada para ser legível no surface; numa imagem
// sem cor viva (capa cinza, preta...), a cor do texto; sem imagem, fallback.
function accentFromImage(candidates, theme, fallback) {
    let best = null, bestScore = 0
    for (const hex of candidates || []) {
        const rgb = parseHex(hex)
        if (!rgb)
            continue
        const c = hsv(rgb)
        if (c.s < 0.25 || c.v < 0.3)
            continue
        const score = c.s * c.v
        if (score > bestScore) {
            best = hex
            bestScore = score
        }
    }
    // capa sem cor viva (preto e branco, cinza): a cor do texto, que contrasta
    // com a barra em tema escuro ou claro; sem capa nenhuma, a cor do tema
    if (!best)
        return (candidates || []).length > 0 ? theme.text : fallback
    return ensureContrast(best, theme.surface, 3, theme.text)
}
