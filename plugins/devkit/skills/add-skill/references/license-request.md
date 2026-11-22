# When the upstream has no license

No license means all rights reserved.
The devkit neither vendors (copying without permission) nor pins (distributing without permission) such a skill.

## What to do instead

1. Tell the user, naming the upstream and the commit, and that the flow stops here.
2. Offer to draft a request to the author, choosing the channel that exists: a GitHub issue on the repository, otherwise an email if an address is public, otherwise a message on the platform where the skill was published.
3. If the user sends it, file an issue on the devkit, so that someone follows the request up. The issue holds:

   - As its goal, that the skill enters the devkit through `/devkit:add-skill`.
   - The upstream, the path and the commit, the date of the request, and the link to it or the note "email sent".
   - Under the heading "Not before", that a license or written permission exists.

   It gets the label `deferred`, because nobody can build it before the author answers.

## Request template

Keep it short and make both outcomes easy.

```text
Title: License for <skill name>

Hi <author>,

We would like to use <skill name> (<url>) at Lyngon, in our skills marketplace, a public repository at <https://github.com/lyngon/devkit>.
The repository has no license file, so we cannot copy or redistribute it.

Would you either add a license (MIT or Apache-2.0 would work for us), or reply here granting Lyngon permission to copy, modify and redistribute the skill publicly, with attribution?

Thanks for the work on it.
<name>, Lyngon
```

Written permission for public redistribution in an issue or email is enough; record the link or a copy of the reply in the provenance record.
Permission scoped to internal use is not enough, since the marketplace is public.
