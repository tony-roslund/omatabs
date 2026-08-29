const fs = require("fs")
const vm = require("vm")
const path = require("path")

const code = fs.readFileSync(path.join(__dirname, "..", "NotesModel.js"), "utf8")
const ctx = {}
vm.createContext(ctx)
vm.runInContext(code, ctx)

function assert(cond, msg) {
  if (!cond) {
    console.error("fail - " + msg)
    process.exit(1)
  }
  console.log("ok - " + msg)
}

const empty = ctx.parse("")
assert(empty.edge === "right" && empty.notes.length === 0 && empty.seeded === false, "empty parse")
const seeded = ctx.seedState()
assert(seeded.seeded === true && seeded.notes[0].title === "Omatabs", "fresh install seeds Omatabs")
assert(seeded.notes[0].body.indexOf("Hover") !== -1, "seed note has instructions")
assert(seeded.notes[0].body.indexOf("**bold**") !== -1, "seed note mentions markdown")
assert(ctx.markdownForDisplay("a\nb") === "a  \nb", "single newlines become hard breaks")
assert(ctx.markdownForDisplay("a\n\nb") === "a\n\nb", "blank lines stay paragraph breaks")
assert(ctx.maxTitleChars() === 24, "title cap is 24 characters")
assert(ctx.clampTitle("x".repeat(40)).length === 24, "clampTitle cuts at the cap")
assert(ctx.newNote("x".repeat(40), "body").title.length === 24, "new notes clamp titles")
assert(ctx.displayTitle({ title: "x".repeat(40), body: "" }).length === 24, "display titles stay capped")

const shortNote = ctx.newNote("Hi", "one")
const longBody = ctx.newNote("Hi", Array(20).fill("a line of peek text").join("\n"))
const shortH = ctx.tabHeightForNote(shortNote, 12, 12, 72, 160)
const longH = ctx.tabHeightForNote(longBody, 12, 12, 72, 160)
assert(shortH <= 160 && longH <= 160, "tab height never exceeds max")
assert(longH >= shortH, "longer bodies grow the tab up to the max")
assert(ctx.tabHeightForTitle("x".repeat(40), 12, 12, 72, 160) <= 160, "long titles stop at max height")

const note = ctx.newNote("Groceries", "milk\neggs")
assert(!!note.id && note.title === "Groceries", "new note")

const packed = ctx.packTabs(
  [note, ctx.newNote("A", "a"), ctx.newNote("B", "b")],
  800,
  { plusHeight: 36, overlap: 10, minStep: 18, fontPx: 12, padding: 12, minHeight: 72, maxHeight: 160, margin: 0 }
)
assert(packed.items.length === 3, "packs three notes")
assert(packed.plusY >= 0, "plus sits in the viewport")
assert(packed.plusY + 36 <= 800 - 90, "plus sits near the bottom")
assert(packed.items[0].y < packed.plusY, "first note stacks above the plus")
assert(packed.items[1].y < packed.items[0].y, "later notes continue upward")
assert(!packed.scroll, "few notes do not scroll")

const many = []
for (let i = 0; i < 20; i++) many.push(ctx.newNote("Note " + i, "body"))
const tight = ctx.packTabs(many, 400, { plusHeight: 36, overlap: 10, minStep: 18, fontPx: 12, padding: 12, minHeight: 72, maxHeight: 160, margin: 0 })
assert(tight.items.length === 20, "packs twenty notes")
assert(tight.scroll === true || tight.contentH <= 400, "overflow either scrolls or fits")

const round = ctx.parse(ctx.serialize({ edge: "left", notes: [note] }))
assert(round.edge === "left", "round-trips edge")
assert(round.notes[0].title === "Groceries", "round-trips title")
assert(ctx.displayTitle({ title: "", body: "  first line  " }) === "first line", "title falls back to body")
assert(ctx.removeNote([note], note.id).length === 0, "remove drops the note")
assert(ctx.colorFor("mint").id === "mint", "known color id")
assert(ctx.colorFor("nope").id === "yellow", "unknown color falls back")
assert(ctx.nextColor([] ) === "yellow", "first note takes the first swatch")
assert(ctx.nextColor([{ color: "yellow" }]) === "mint", "next unused swatch")
const colored = ctx.parse(ctx.serialize({ edge: "right", notes: [ctx.newNote("X", "y", "lavender")] }))
assert(colored.notes[0].color === "lavender", "round-trips color")
const written = ctx.parse(ctx.serialize({ edge: "right", notes: [] }))
assert(written.seeded === true && written.notes.length === 0, "persisted empty deck stays unseeded")
