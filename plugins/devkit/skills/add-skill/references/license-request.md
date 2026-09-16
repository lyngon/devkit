# When the upstream has no license

No license means all rights reserved.
The devkit neither vendors (copying without permission) nor pins (distributing without permission) such a skill.

## What to do instead

1. Tell the user, naming the upstream and the commit, and that the flow stops here.
2. Offer to draft a request to the author, choosing the channel that exists: a GitHub issue on the repository, otherwise an email if an address is public, otherwise a message on the platform where the skill was published.
3. If the user sends it, add a line to `docs/TODO.md`:

   ```md
   - {YYYY-MM-DD}: Follow up on the license request for {owner/repo/path} ({link to issue or note "email sent"}); re-run `/devkit:add-skill` once a license or written permission exists.
   ```

## Request template

Keep it short and make both outcomes easy.

```text
Title: License for <skill name>

Hi <author>,

We would like to use <skill name> (<url>) at Lyngon, in our internal skills marketplace.
The repository has no license file, so we cannot copy or redistribute it.

Would you either add a license (MIT or Apache-2.0 would work for us), or reply here granting Lyngon permission to copy, modify and redistribute the skill internally?

Thanks for the work on it.
<name>, Lyngon
```

Written permission in an issue or email is enough; record the link or a copy of the reply in the provenance record.
