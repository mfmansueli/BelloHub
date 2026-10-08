# Agent notes

Parallel agents (see the memory note on parallel work) never edit `docs/PROGRESS.md`, `DESIGN.md` or
`BelloHub/SupportFiles/Localizable.xcstrings`. Each writes `docs/agent-notes/<name>.md` with: what was built, files
owned, decisions and assumptions (ASSUMPTION-n candidates), design additions, findings, open questions, and the strings
batch files it added. The coordinator merges the notes into PROGRESS.md and DESIGN.md and regenerates the catalog.
