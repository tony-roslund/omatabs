import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "NotesModel.js" as NotesModel

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property var notes: []
  property int notesRev: 0
  property string edge: "right"
  property bool editorOpen: false
  property bool editorIsNew: true
  property string editingId: ""
  property string draftTitle: ""
  property string draftBody: ""
  property string draftColor: "yellow"
  property string hoveredId: ""
  property int hoveredIndex: -1
  property bool plusHovered: false

  readonly property bool onRight: root.edge !== "left"
  readonly property int spineWidth: Style.space(28)
  readonly property int peekWidth: Style.space(240)
  readonly property int cardWidth: Style.space(300)
  readonly property int cardHeight: Style.space(280)
  readonly property int plusHeight: Style.space(20)
  readonly property int hang: Math.max(Style.cornerRadius, 4) + Math.max(2, Style.space(2))
  readonly property int maxPeekWidth: {
    var sw = (strip.screen && strip.screen.width > 0) ? strip.screen.width : 1600
    return Math.max(root.cardWidth, Math.min(Style.space(640), Math.round(sw * 0.45)))
  }
  readonly property var hoveredTabItem: {
    if (root.hoveredIndex < 0) return stack
    var tab = tabRepeater.itemAt(root.hoveredIndex)
    return tab ? tab : stack
  }
  readonly property color paper: Color.menu.background
  readonly property color ink: Color.menu.text
  readonly property var paperBorder: Border.flat(Color.menu.border, Math.max(1, Style.space(1)))
  readonly property string pluginPath: root.manifest && root.manifest.__sourceDir ? String(root.manifest.__sourceDir) : ""
  readonly property string stateHelper: root.pluginPath + "/libexec/omatabs-state"
  readonly property int helperTimeoutMs: 5000
  readonly property int helperKillMs: 500
  property bool persistQueued: false

  function open(payloadJson) {
    root.startNew()
  }

  function close() {
    root.closeEditor()
  }

  function toggle() {
    if (root.editorOpen) root.closeEditor()
    else root.startNew()
  }

  function startNew() {
    root.editorIsNew = true
    root.editingId = ""
    root.draftTitle = ""
    root.draftBody = ""
    root.draftColor = NotesModel.nextColor(root.notes)
    root.hoveredId = ""
    root.hoveredIndex = -1
    root.plusHovered = false
    root.editorOpen = true
    Qt.callLater(function() {
      editorCard.setDraft("", "")
      editorCard.takeFocus()
    })
  }

  function editNote(id) {
    var note = NotesModel.findNote(root.notes, id)
    if (!note) return
    root.editorIsNew = false
    root.editingId = note.id
    root.draftTitle = note.title
    root.draftBody = note.body
    root.draftColor = note.color
    root.hoveredId = ""
    root.hoveredIndex = -1
    root.plusHovered = false
    root.editorOpen = true
    Qt.callLater(function() {
      editorCard.setDraft(note.title, note.body)
      editorCard.takeFocus()
    })
  }

  function closeEditor() {
    root.editorOpen = false
    root.editingId = ""
    root.draftTitle = ""
    root.draftBody = ""
  }

  function saveDraft(title, body, colorId) {
    var trimmedTitle = String(title || "")
    var trimmedBody = String(body || "")
    if (!trimmedTitle.trim() && !trimmedBody.trim()) {
      root.closeEditor()
      return
    }
    var color = colorId || root.draftColor
    var note
    if (root.editorIsNew) {
      note = NotesModel.newNote(trimmedTitle, trimmedBody, color)
    } else {
      note = NotesModel.findNote(root.notes, root.editingId)
      if (!note) note = NotesModel.newNote(trimmedTitle, trimmedBody, color)
      else {
        note = {
          id: note.id,
          title: trimmedTitle,
          body: trimmedBody,
          color: color,
          created: note.created,
          updated: Date.now()
        }
      }
    }
    root.setNotes(NotesModel.upsertNote(root.notes, note))
    root.persist()
    root.closeEditor()
  }

  function setNoteColor(id, colorId) {
    var note = NotesModel.findNote(root.notes, id)
    if (!note) return
    root.setNotes(NotesModel.upsertNote(root.notes, {
      id: note.id,
      title: note.title,
      body: note.body,
      color: colorId,
      created: note.created,
      updated: Date.now()
    }))
    root.persist()
    if (root.editingId === id) root.draftColor = colorId
  }

  function deleteNote(id) {
    root.setNotes(NotesModel.removeNote(root.notes, id))
    root.persist()
    if (root.editingId === id) root.closeEditor()
  }

  function deleteEditing() {
    if (root.editingId) root.deleteNote(root.editingId)
    else root.closeEditor()
  }

  function pickDraftColor(id) {
    root.draftColor = id
    if (!root.editorIsNew && root.editingId)
      root.setNoteColor(root.editingId, id)
  }

  function persist() {
    if (saveProc.running || loadProc.running) {
      root.persistQueued = true
      return
    }
    root.persistQueued = false
    saveProc.payload = NotesModel.serialize({ edge: root.edge, notes: root.notes })
    saveProc.command = ["python3", root.stateHelper, "save"]
    saveTimeout.restart()
    saveProc.running = true
  }

  function loadState(raw) {
    var state = NotesModel.parse(raw)
    var needsSeed = !state.seeded && state.notes.length === 0
    if (needsSeed) state = NotesModel.seedState()
    root.edge = state.edge
    root.setNotes(state.notes)
    if (needsSeed) root.persist()
  }

  function setNotes(list) {
    var next = []
    var src = list || []
    for (var i = 0; i < src.length; i++) next.push(src[i])
    root.notes = next
    root.notesRev = root.notesRev + 1
  }

  Text {
    id: titleMeter
    visible: false
    textFormat: Text.PlainText
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.body
    font.bold: true
    wrapMode: Text.NoWrap
  }

  function titleTabHeights() {
    var out = []
    // Spine has aaPad on each end, plus room so the rotated title is not tight.
    var pad = Style.space(24) + 4
    var minH = Style.space(32)
    var list = root.notes || []
    for (var i = 0; i < list.length; i++) {
      titleMeter.text = NotesModel.displayTitle(list[i])
      out.push(Math.max(minH, Math.ceil(titleMeter.implicitWidth) + pad))
    }
    return out
  }

  function layoutFor(available) {
    var inner = Math.max(Style.space(32), Number(available) || 0)
    return NotesModel.packTabs(root.notes, available, {
      plusHeight: root.plusHeight,
      overlap: Style.space(8),
      minStep: Style.space(16),
      fontPx: Style.font.body,
      padding: Style.space(8),
      minHeight: Style.space(32),
      maxHeight: inner,
      bottomOffset: Style.space(100),
      titleOnly: true,
      heights: root.titleTabHeights()
    })
  }

  function noteAt(index) {
    if (index < 0 || index >= root.notes.length) return null
    return root.notes[index]
  }

  Component.onCompleted: {
    loadProc.command = ["python3", root.stateHelper, "load"]
    loadTimeout.restart()
    loadProc.running = true
  }

  function stopHelper(proc, termTimer, killTimer) {
    termTimer.stop()
    if (!proc.running) {
      killTimer.stop()
      return
    }
    proc.signal(15)
    killTimer.restart()
  }

  Process {
    id: loadProc
    stdout: StdioCollector {
      id: loadOut
      waitForEnd: true
    }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(exitCode) {
      loadTimeout.stop()
      loadKill.stop()
      root.loadState(exitCode === 0 ? String(loadOut.text || "") : "")
      if (root.persistQueued && !saveProc.running) root.persist()
    }
  }

  Timer {
    id: loadTimeout
    interval: root.helperTimeoutMs
    repeat: false
    onTriggered: root.stopHelper(loadProc, loadTimeout, loadKill)
  }

  Timer {
    id: loadKill
    interval: root.helperKillMs
    repeat: false
    onTriggered: if (loadProc.running) loadProc.signal(9)
  }

  Process {
    id: saveProc
    property string payload: ""
    stdinEnabled: true
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onStarted: saveProc.write(saveProc.payload)
    onExited: function(exitCode) {
      saveTimeout.stop()
      saveKill.stop()
      if (exitCode === 0 && saveProc.payload) {
        var saved = NotesModel.parse(saveProc.payload)
        if (saved.notes) root.setNotes(saved.notes)
      }
      saveProc.payload = ""
      if (root.persistQueued) root.persist()
    }
  }

  Timer {
    id: saveTimeout
    interval: root.helperTimeoutMs
    repeat: false
    onTriggered: root.stopHelper(saveProc, saveTimeout, saveKill)
  }

  Timer {
    id: saveKill
    interval: root.helperKillMs
    repeat: false
    onTriggered: if (saveProc.running) saveProc.signal(9)
  }

  IpcHandler {
    target: "tony.omatabs"
    function ping(): string { return "ok" }
    function newNote(): string { root.startNew(); return "ok" }
    function edge(side: string): string {
      if (side === "left" || side === "right") {
        root.edge = side
        root.persist()
      }
      return root.edge
    }
  }

  PanelWindow {
    id: strip
    visible: true
    color: "transparent"
    // Wide enough for a content-sized peek. Input is masked to the spines
    // (or the open note), so this does not steal the rest of the screen.
    implicitWidth: root.maxPeekWidth + root.hang
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "omarchy-omatabs"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors {
      top: true
      bottom: true
      right: root.onRight
      left: !root.onRight
    }
    mask: Region { item: root.hoveredTabItem }

    Item {
      id: stack
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.right: root.onRight ? parent.right : undefined
      anchors.left: root.onRight ? undefined : parent.left
      anchors.topMargin: Style.gapsOut + Style.space(28)
      anchors.bottomMargin: Style.gapsOut
      width: root.spineWidth

      readonly property var pack: {
        var _rev = root.notesRev
        var _px = titleMeter.font.pixelSize
        var _w = titleMeter.implicitWidth
        return root.layoutFor(height)
      }

      Item {
        id: plusTab
        z: 1000
        width: root.plusHeight + root.hang
        height: root.plusHeight
        y: stack.pack.plusY
        anchors.right: root.onRight ? parent.right : undefined
        anchors.left: root.onRight ? undefined : parent.left
        anchors.rightMargin: root.onRight ? -root.hang : 0
        anchors.leftMargin: root.onRight ? 0 : -root.hang

        BorderSurface {
          anchors.fill: parent
          color: root.paper
          borderSpec: root.paperBorder
          radius: Style.cornerRadius
          antialiasing: true
        }

        Text {
          anchors.centerIn: parent
          anchors.horizontalCenterOffset: root.onRight ? -root.hang / 2 : root.hang / 2
          text: "+"
          color: root.ink
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.startNew()
        }
      }

      Repeater {
        id: tabRepeater
        model: root.notesRev >= 0 ? root.notes.length : 0
        delegate: NoteTab {
          required property int index
          readonly property var note: {
            var _rev = root.notesRev
            return root.noteAt(index)
          }
          readonly property var slot: {
            var _rev = root.notesRev
            var items = stack.pack.items
            return (items && items[index]) ? items[index] : { y: 0, height: Style.space(72) }
          }
          readonly property string noteId: note ? note.id : ""
          slotY: slot.y
          slotHeight: slot.height
          stackHeight: stack.height
          z: hovered ? 2000 + index : index
          tilt: {
            var tilts = [2.4, 1.8, 2.8, 2.1, 1.6, 2.6]
            return tilts[index % tilts.length]
          }
          anchors.right: root.onRight ? parent.right : undefined
          anchors.left: root.onRight ? undefined : parent.left
          anchors.rightMargin: root.onRight ? -root.hang : 0
          anchors.leftMargin: root.onRight ? 0 : -root.hang
          onRight: root.onRight
          hang: root.hang
          hovered: !root.editorOpen && root.hoveredId === noteId
          editing: root.editorOpen && !root.editorIsNew && root.editingId === noteId
          title: note ? NotesModel.displayTitle(note) : "Untitled"
          body: note ? String(note.body || "") : ""
          colorId: note && note.color ? note.color : "yellow"
          spineWidth: root.spineWidth
          peekWidth: root.peekWidth
          maxPeekWidth: root.maxPeekWidth
          onClicked: if (noteId) root.editNote(noteId)
          onColorPicked: function(id) { if (noteId) root.setNoteColor(noteId, id) }
          onDeleteClicked: if (noteId) root.deleteNote(noteId)
          onHoverChanged: function(isHovered) {
            if (root.editorOpen) return
            if (isHovered) {
              collapseTimer.stop()
              root.hoveredId = noteId
              root.hoveredIndex = index
              root.plusHovered = false
            } else if (root.hoveredId === noteId) {
              collapseTimer.restart()
            }
          }
        }
      }

      Timer {
        id: collapseTimer
        interval: 20
        repeat: false
        onTriggered: {
          if (root.editorOpen) return
          root.hoveredId = ""
          root.hoveredIndex = -1
          root.plusHovered = false
        }
      }
    }
  }

  PanelWindow {
    id: stage
    visible: root.editorOpen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    implicitWidth: screen && screen.width > 0 ? screen.width : 1920
    implicitHeight: screen && screen.height > 0 ? screen.height : 1080
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "omarchy-omatabs-editor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.editorOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: editorCard }

    EditorCard {
      id: editorCard
      maxWidth: {
        var sw = (stage.screen && stage.screen.width > 0) ? stage.screen.width : 1600
        return Math.max(root.cardWidth, Math.min(Style.space(720), Math.round(sw * 0.55)))
      }
      maxHeight: {
        var sh = (stage.screen && stage.screen.height > 0) ? stage.screen.height : 1000
        return Math.max(root.cardHeight, sh - Style.gapsOut * 4)
      }
      anchors.centerIn: parent
      hang: 0
      onRight: true
      isNew: root.editorIsNew
      colorId: root.draftColor
      onSaveRequested: function(title, body, colorId) { root.saveDraft(title, body, colorId) }
      onCancelRequested: root.closeEditor()
      onDeleteRequested: root.deleteEditing()
      onColorPicked: function(id) { root.pickDraftColor(id) }
    }
  }
}
