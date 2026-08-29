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
  if (!raw) return state
  try {
    var data = JSON.parse(String(raw))
  } catch (e) {
    return state
  }
  if (!data || typeof data !== "object") return state
  if (data.edge === "left" || data.edge === "right") state.edge = data.edge
  if (data.seeded === true) state.seeded = true
  var notes = []
  var list = Array.isArray(data.notes) ? data.notes : []
  for (var i = 0; i < list.length; i++) {
    var note = normalizeNote(list[i])
    if (note) notes.push(note)
  }
  state.notes = notes
  return state
}

function serialize(state) {
  var edge = state && state.edge === "left" ? "left" : "right"
  var notes = []
  var list = state && Array.isArray(state.notes) ? state.notes : []
  for (var i = 0; i < list.length; i++) {
    var note = normalizeNote(list[i])
    if (note) notes.push(note)
  }
  return JSON.stringify({ version: 1, edge: edge, seeded: true, notes: notes }, null, 2) + "\n"
}

function normalizeNote(value) {
  if (!value || typeof value !== "object") return null
  var id = String(value.id || "").trim()
  if (!id) return null
  var title = String(value.title == null ? "" : value.title)
  var body = String(value.body == null ? "" : value.body)
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
    title: String(title || ""),
    body: String(body || ""),
    color: colorFor(colorId).id,
    created: now,
    updated: now
  }
}

function displayTitle(note) {
  if (!note) return "Untitled"
  var title = String(note.title || "").replace(/\s+/g, " ").trim()
  if (title) return title
  var body = String(note.body || "").replace(/\s+/g, " ").trim()
  if (body) return body.slice(0, 40)
  return "Untitled"
}

// Qt CommonMark collapses single newlines. Keep typed line breaks as hard
// breaks so a saved note still looks like the note, with markdown applied.
function markdownForDisplay(body) {
  return String(body || "").replace(/([^\n])\n(?!\n)/g, "$1  \n")
}

function tabHeightForTitle(title, fontPx, padding, minH, maxH) {
  var t = String(title || "Untitled")
  var h = Math.round(t.length * fontPx * 0.62 + padding * 2)
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
  var heights = []
  for (var i = 0; i < n; i++)
    heights.push(tabHeightForTitle(displayTitle(notes[i]), fontPx, pad, minH, maxH))

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
  if (!found) next.push(normalized)
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
