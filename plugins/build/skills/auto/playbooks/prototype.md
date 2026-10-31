# Prototype

You own the decision, not the code.
The prototype is a throwaway instrument, and the real build follows the Feature playbook.

This is the one playbook where the smallest change of the principle `laziness-protocol` and the bar for verification invert.
Speed beats polish, the quality of the code does not matter, and nothing is planned.
The rigor is in picking the right design cheaply.
Propose variations the operator did not ask for, and throw an approach away to try another.

## What must hold

- The decision the prototype exists to make is named: which layout, which interaction, which density, or for an empirical fork which behavior, timing or approach. Without a decision there is no prototype, and the task follows the Feature playbook.
- When the design space was open, prior art was searched and its themes, palettes and layouts summarized, and the operator picked the directions before anything was built. When the direction was set, this was skipped.
- The prototype lives in `tmp/prototype/<slug>/`, in the directory `tmp/` at the root of the repository, apart from the production source. A visual decision gets plain HTML, CSS and JavaScript, or the lightest stack that renders the idea, with dependencies from a CDN and a server that reloads. A behavior or timing decision gets the smallest script that exercises the question. No production framework, no tests, no abstractions.
- Alternatives are built behind one switcher (buttons or a key), each variant labeled. This is the principle `exhaust-the-design-space` made cheap.

## Proof owed

- The thing being decided, observed on the surface where it matters. A visual decision has a screenshot of each variant and its interaction driven. A behavior or timing decision has the timing logged, the output printed or the rendering watched. The observation is the test here, not an assertion.

The output is the decision and the throwaway artifact, never code to ship.
An empirical fork is settled by what you observed, so carry on with the chosen direction under the Feature playbook, or through `build:architect` for its shape, which ends with `build:pull-request`.
A visual or preference decision is the operator's: present the variants, the trade-offs and your recommendation, and stop with one question.

**Reply:** the variants explored, the evidence (screenshots for a visual decision, the observed output or timing for a behavioral one), the trade-offs, your recommendation and the path of the prototype. Say plainly that the prototype is throwaway.
