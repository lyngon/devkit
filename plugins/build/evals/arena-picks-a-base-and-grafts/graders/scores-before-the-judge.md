---
type: tool_order
before: { tool: Write, input_match: '"file_path"\s*:\s*"[^"]*/home/cwd/tmp/arena/[^"]*synthesis\.md"[\s\S]*([Ss]cor|[Cc]riteri)' }
after: { tool: Agent, input_match: '[Rr]ubric' }
---
