function maxTitleChars() {
  return 24
}

function maxBodyChars() {
  return 8192
}

function maxIdChars() {
  return 64
}

function maxNotes() {
  return 64
}

function maxFileBytes() {
  return 256 * 1024
}

function maxJsonDepth() {
  return 6
}

function maxLinkChars() {
  return 256
}

function clampTitle(title) {
  var t = String(title == null ? "" : title)
  var max = maxTitleChars()
  if (t.length > max) t = t.slice(0, max)
  return t
}

function clampBody(body) {
  var t = String(body == null ? "" : body)
  var max = maxBodyChars()
  if (t.length > max) t = t.slice(0, max)
  return t
}

function validId(id) {
  var s = String(id == null ? "" : id)
  if (!s || s.length > maxIdChars()) return false
  for (var i = 0; i < s.length; i++) {
    var c = s.charCodeAt(i)
    if (c < 32 || c === 127 || c === 47 || c === 92) return false
  }
  return true
}

function jsonDepth(value, depth) {
  var d = depth || 1
  if (d > maxJsonDepth()) return false
  if (value && typeof value === "object") {
    if (Array.isArray(value)) {
      var limit = Math.min(value.length, maxNotes())
      for (var i = 0; i < limit; i++) {
        if (!jsonDepth(value[i], d + 1)) return false
      }
      return true
    }
    var n = 0
    for (var k in value) {
      if (!Object.prototype.hasOwnProperty.call(value, k)) continue
      n += 1
      if (n > 16) return false
      if (!jsonDepth(value[k], d + 1)) return false
    }
  }
  return true
}

function sanitizeLink(url) {
  var href = String(url || "").trim()
  if (href.charAt(0) === "<" && href.charAt(href.length - 1) === ">")
    href = href.slice(1, -1)
  if (!href || href.length > maxLinkChars()) return ""
  if (/[\s<>]/.test(href)) return ""
  if (!/^(https?|mailto):[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%-]+$/i.test(href)) return ""
  return href
}

function sanitizeBody(body) {
  var text = clampBody(body)
  text = text.replace(/<(https?:\/\/[^>\s]+)>/gi, function(_, url) {
    return sanitizeLink(url)
  })
  text = text.replace(/<[A-Za-z\/!?][^>]*>/g, "")
  text = text.replace(/!\[([^\]]*)\](?:\([^)]*\))?/g, "")
  text = text.replace(/\[([^\]]+)\]\(([^)]*)\)/g, function(_, label, url) {
    var href = sanitizeLink(url)
    return href ? ("[" + label + "](" + href + ")") : label
  })
  text = text.replace(/^\[([^\]]+)\]:\s*(\S+)/gm, function(_, ref, url) {
    var href = sanitizeLink(url)
    return href ? ("[" + ref + "]: " + href) : ""
  })
  return text
}

function emptyState() {
  return { version: 1, edge: "right", seeded: false, notes: [] }
}

function welcomeNote() {
  var now = Date.now()
  return {
    id: "omatabs-welcome",
    title: "Omatabs",
    body: "Hover a tab to peek.\nClick to edit.\n\nEnter saves. Shift+Enter is a new line.\n+ starts a new note.\n\nMarkdown works: **bold**, *italic*, `code`, and lists.",
    color: "yellow",
    created: now,
    updated: now
  }
}

function seedState() {
  return { version: 1, edge: "right", seeded: true, notes: [welcomeNote()] }
}

function parse(raw) {
  var state = emptyState()
  var source = String(raw == null ? "" : raw)
  if (!source) return state
  if (source.length > maxFileBytes()) return state
  var data
  try {
    data = JSON.parse(source)
  } catch (e) {
    return state
  }
  if (!data || typeof data !== "object" || Array.isArray(data)) return state
  if (!jsonDepth(data)) return state
  if (data.edge === "left" || data.edge === "right") state.edge = data.edge
  if (data.seeded === true) state.seeded = true
  var notes = []
  var seen = ({})
  var list = Array.isArray(data.notes) ? data.notes : []
  for (var i = 0; i < list.length; i++) {
    var note = normalizeNote(list[i])
    if (!note || seen[note.id]) continue
    seen[note.id] = true
    notes.push(note)
    if (notes.length >= maxNotes()) break
  }
  state.notes = notes
  return state
}

function serialize(state) {
  var edge = state && state.edge === "left" ? "left" : "right"
  var notes = []
  var seen = ({})
  var list = state && Array.isArray(state.notes) ? state.notes : []
  for (var i = 0; i < list.length; i++) {
    var note = normalizeNote(list[i])
    if (!note || seen[note.id]) continue
    seen[note.id] = true
    notes.push(note)
    if (notes.length >= maxNotes()) break
  }
  return JSON.stringify({ version: 1, edge: edge, seeded: true, notes: notes }, null, 2) + "\n"
}

function normalizeNote(value) {
  if (!value || typeof value !== "object") return null
  var id = String(value.id || "").trim()
  if (!validId(id)) return null
  var title = clampTitle(value.title)
  var body = sanitizeBody(value.body)
  var created = Number(value.created)
  var updated = Number(value.updated)
  if (!isFinite(created) || created <= 0) created = Date.now()
  if (!isFinite(updated) || updated <= 0) updated = created
  return {
    id: id,
    title: title,
    body: body,
    color: colorFor(value.color).id,
    created: Math.round(created),
    updated: Math.round(updated)
  }
}

function palette() {
  return [
    { id: "yellow", paper: "#F3E07A", ink: "#2C2710" },
    { id: "mint", paper: "#B6E3C4", ink: "#173022" },
    { id: "blue", paper: "#C7D8F0", ink: "#1A2433" },
    { id: "lavender", paper: "#D9C4F0", ink: "#2A1D33" },
    { id: "peach", paper: "#F2C4A8", ink: "#332016" },
    { id: "rose", paper: "#F0C1D2", ink: "#331820" }
  ]
}

function colorFor(id) {
  var list = palette()
  var key = String(id || "")
  for (var i = 0; i < list.length; i++) {
    if (list[i].id === key) return list[i]
  }
  return list[0]
}

function nextColor(notes) {
  var list = palette()
  var used = ({})
  var items = Array.isArray(notes) ? notes : []
  for (var i = 0; i < items.length; i++) {
    if (items[i] && items[i].color) used[items[i].color] = true
  }
  for (var j = 0; j < list.length; j++) {
    if (!used[list[j].id]) return list[j].id
  }
  return list[items.length % list.length].id
}

function newId() {
  return Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 8)
}

function newNote(title, body, colorId) {
  var now = Date.now()
  return {
    id: newId(),
    title: clampTitle(title),
    body: sanitizeBody(body || ""),
    color: colorFor(colorId).id,
    created: now,
    updated: now
  }
}

function displayTitle(note) {
  if (!note) return "Untitled"
  var title = clampTitle(String(note.title || "").replace(/\s+/g, " ").trim())
  if (title) return title
  var body = String(note.body || "").replace(/\s+/g, " ").trim()
  if (body) return clampTitle(body)
  return "Untitled"
}

// Qt CommonMark collapses single newlines. Keep typed line breaks as hard
// breaks so a saved note still looks like the note, with markdown applied.
function markdownForDisplay(body) {
  return String(body || "").replace(/([^\n])\n(?!\n)/g, "$1  \n")
}

function tabHeightForTitle(title, fontPx, padding, minH, maxH) {
  var t = clampTitle(title || "Untitled")
  var h = Math.round(t.length * fontPx * 0.62 + padding * 2)
  if (h < minH) h = minH
  if (h > maxH) h = maxH
  return h
}

function tabHeightForNote(note, fontPx, padding, minH, maxH) {
  var titleH = tabHeightForTitle(displayTitle(note), fontPx, padding, minH, maxH)
  var body = note && note.body != null ? String(note.body) : ""
  var rawLines = body.length ? body.split("\n").length : 0
  var wrapLines = Math.max(rawLines, Math.ceil(body.length / 36))
  var needed = padding + fontPx + 6 + wrapLines * (fontPx + 4) + 28 + padding
  var h = Math.max(titleH, needed)
  if (h < minH) h = minH
  if (h > maxH) h = maxH
  return h
}

// Park the + tab near the bottom of the edge, then stack notes upward.
// When they would run off the top, overlap increases. If even the minimum
// visible slice cannot fit, the stack becomes scrollable.
function packTabs(notes, available, opts) {
  opts = opts || {}
  var plusH = Math.max(1, Number(opts.plusHeight) || 36)
  var overlap = Math.max(0, Number(opts.overlap) || 10)
  var minStep = Math.max(8, Number(opts.minStep) || 18)
  var fontPx = Math.max(8, Number(opts.fontPx) || 12)
  var pad = Math.max(0, Number(opts.padding) || 12)
  var minH = Math.max(minStep, Number(opts.minHeight) || 72)
  var maxH = Math.max(minH, Number(opts.maxHeight) || 160)
  var bottomOffset = Math.max(0, Number(opts.bottomOffset) || 100)

  var inner = Math.max(0, Number(available) || 0)
  if (inner < plusH) inner = plusH
  var plusY = inner - plusH - bottomOffset
  if (plusY < 0) plusY = 0

  var n = Array.isArray(notes) ? notes.length : 0
  var titleOnly = opts.titleOnly === true
  var given = Array.isArray(opts.heights) ? opts.heights : null
  var heights = []
  for (var i = 0; i < n; i++) {
    var h
    if (given && isFinite(Number(given[i])))
      h = Math.round(Number(given[i]))
    else if (titleOnly)
      h = tabHeightForTitle(displayTitle(notes[i]), fontPx, pad, minH, maxH)
    else
      h = tabHeightForNote(notes[i], fontPx, pad, minH, maxH)
    if (h < minH) h = minH
    if (h > maxH) h = maxH
    heights.push(h)
  }

  function layout(ov) {
    var items = []
    var bottom = plusY + ov
    for (var i = 0; i < n; i++) {
      var y = bottom - heights[i]
      items.push({ id: notes[i].id, y: y, height: heights[i] })
      bottom = y + ov
    }
    var topY = n > 0 ? items[n - 1].y : plusY
    return { items: items, topY: topY }
  }

  var packed = layout(overlap)
  var scroll = false
  if (n > 0 && packed.topY < 0) {
    var extra = -packed.topY
    var ov = overlap + extra / n
    var minHgt = heights[0]
    for (var j = 1; j < n; j++) if (heights[j] < minHgt) minHgt = heights[j]
    var maxOv = Math.max(0, minHgt - minStep)
    if (ov > maxOv) {
      ov = maxOv
      scroll = true
    }
    packed = layout(ov)
  }

  var contentH = plusY + plusH
  if (n > 0) contentH = Math.max(contentH, packed.items[0].y + packed.items[0].height) - Math.min(0, packed.topY)
  return {
    plusY: plusY,
    plusH: plusH,
    items: packed.items,
    scroll: scroll,
    contentH: contentH
  }
}

function upsertNote(notes, note) {
  var next = []
  var found = false
  var list = Array.isArray(notes) ? notes : []
  var normalized = normalizeNote(note)
  if (!normalized) return list.slice()
  for (var i = 0; i < list.length; i++) {
    if (list[i] && list[i].id === normalized.id) {
      next.push(normalized)
      found = true
    } else {
      next.push(list[i])
    }
  }
  if (!found) {
    if (next.length >= maxNotes()) return next
    next.push(normalized)
  }
  return next
}

function removeNote(notes, id) {
  var next = []
  var list = Array.isArray(notes) ? notes : []
  var key = String(id || "")
  for (var i = 0; i < list.length; i++) {
    if (list[i] && list[i].id === key) continue
    next.push(list[i])
  }
  return next
}

function findNote(notes, id) {
  var list = Array.isArray(notes) ? notes : []
  var key = String(id || "")
  for (var i = 0; i < list.length; i++) {
    if (list[i] && list[i].id === key) return list[i]
  }
  return null
}
