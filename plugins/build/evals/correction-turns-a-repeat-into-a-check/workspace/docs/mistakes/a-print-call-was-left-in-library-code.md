# A print call was left in library code

- **Date**: 2026-09-02
- **Caught in**: [feat(orders): price a bundle as the sum of its lines](https://github.com/example/shop/pull/187)

The agent debugged the bundle price with a print call in `src/orders/bundle.py` and left it in the change.
The reviewer found it on the pull request, and the library logs through `logging` everywhere else.
