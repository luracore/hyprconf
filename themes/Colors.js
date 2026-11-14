.pragma library

// Completa um tema de themes/*.json (neutrals + palette + roles) numa tabela
// plana de cores. Usado pelo Quickshell (via symlink) e pelo
// themes/converters/main.js (Node): as regras ficam só aqui.
//
// Resultado: background, surface, overlay, outline, muted, text,
//            red, orange, yellow, green, cyan, blue, magenta,
//            primary, secondary, tertiary, error, warning, success, info,
//            e on<Nome> (cor de texto legível por cima) para cada cor
//            da paleta e cada papel.

const NEUTRALS = ["background", "surface", "overlay", "outline", "muted", "text"]

// para as cores obrigatórias que faltarem (ou se o arquivo falhar)
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

function onColor(bg, n) {
    return contrast(bg, n.background) >= contrast(bg, n.text) ? n.background : n.text
}

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

function resolve(theme, fallback, warn) {
    warn = warn || function () {}
    theme = theme || {}
    fallback = fallback || FALLBACK

    const tn = theme.neutrals || {}, tp = theme.palette || {}
    const fn = fallback.neutrals, fp = fallback.palette

    const n = {}
    n.background = pick(tn, "background", fn.background, warn)
    n.text = pick(tn, "text", fn.text, warn)
    n.surface = pick(tn, "surface", mix(n.background, n.text, 0.06), warn)
    n.overlay = pick(tn, "overlay", mix(n.surface, n.text, 0.08), warn)
    n.outline = pick(tn, "outline", mix(n.background, n.text, 0.25), warn)
    n.muted = pick(tn, "muted", mix(n.background, n.text, 0.5), warn)

    const p = {}
    for (const key of ["red", "yellow", "green", "cyan", "blue", "magenta"]) {
        if (tp[key] === undefined)
            warn("paleta sem '" + key + "', usando a do fallback")
        p[key] = pick(tp, key, fp[key], warn)
    }
    p.orange = pick(tp, "orange", mix(p.red, p.yellow, 0.5), warn)

    const out = Object.assign({}, n, p)

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

    // Object.keys é uma cópia: num for-in sobre out, cada onX criado também
    // seria visitado (onOnX, ...) para sempre.
    for (const key of Object.keys(out)) {
        if (NEUTRALS.indexOf(key) >= 0)
            continue
        out["on" + key.charAt(0).toUpperCase() + key.slice(1)] = onColor(out[key], n)
    }

    return out
}

function hsv(rgb) {
    const [r, g, b] = rgb.map(c => c / 255)
    const max = Math.max(r, g, b), min = Math.min(r, g, b)
    return { s: max === 0 ? 0 : (max - min) / max, v: max }
}

function ensureContrast(fg, bg, ratio, towards) {
    let out = fg
    for (let t = 0.1; contrast(out, bg) < ratio && t <= 1; t += 0.1)
        out = mix(fg, towards, t)
    return out
}

// candidates: cores da capa do álbum (saída do ColorQuantizer)
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
    // capa sem cor viva (cinza, preto e branco): a cor do texto, que contrasta
    // com a barra em tema escuro ou claro
    if (!best)
        return (candidates || []).length > 0 ? theme.text : fallback
    return ensureContrast(best, theme.surface, 3, theme.text)
}
