# Guidelines for AI Coding Agents

> [!IMPORTANT]
> Every agent working on this codebase must adhere to these standards.

## 1. Documentation Integrity (Docs-Sync)

- **Rule**: Documentation MUST be updated immediately after any code-level API change. 
- **Rule**: Documentation MUST reflect the **current** state of the library only.
- **Rule**: Do not use "transitionary" boxes or alerts (e.g., "Now updated to...") in the reference files. We dont need backward compatibility.
- **Rule**: Avoid "meta-talk" or conversational comments in examples and documentation. Keep comments concise and focused on the code's function.
- **Action**: If you add/remove/update a function, update its corresponding `.md` file in the `docs/` folder. If you change a parameter type, update the signature in the documentation.
- **Goal**: Ensure that the library remains "Plug-and-Play" for human users at all times.