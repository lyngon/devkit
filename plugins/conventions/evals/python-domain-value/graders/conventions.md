---
type: llm
focus: { source: file, path: libs/orders/src/orders/domain/order.py }
---
PASS if the module is a domain value type that follows the Lyngon Python conventions: every function signature is fully type-hinted, the value is immutable (a frozen dataclass or equivalent), no validation library such as pydantic is imported, no print call and no async code appears, and imports are absolute and import modules rather than names.
FAIL if any signature lacks type hints, the class is mutable, a validation library is used, the file contains print or async, or a name is imported from a module instead of the module itself.
