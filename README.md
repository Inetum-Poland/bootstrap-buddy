# Bootstrap Buddy

**Bootstrap Buddy is a macOS authorization plugin that allows MDM administrators to escrow Bootstrap Token to MDM server (if supported) on Mac computers that have failed to do so.**

It is entirely based on [Escrow Buddy](https://github.com/macadmins/escrow-buddy) from **Netflix Client Systems Engineering** team, so the credit goes to them.

---

## Requirements

- Your managed Macs must:
    - be enrolled in an MDM
    - have macOS Mojave 10.14.4 or newer
- Your MDM must:
    - support Bootstrap Token escrow
    - have the ability to install packages and run shell scripts

---

## Deployment

1. Use your MDM to **install the [latest Bootstrap Buddy installer package](https://github.com/bsojka/bootstrap-buddy/releases/latest)** on your Mac computers.

    You can choose to install on all computers or limit to those that need Bootstrap Token escrowed.

That's it! The next time a Volume Owner logs in to the Mac, a new Bootstrap Token will be escrowed to your MDM.

---

## Support

**WIKI WILL BE CREATED SOON™**

See the wiki for [Frequently Asked Questions](https://github.com/bsojka/bootstrap-buddy/wiki/FAQ) and [Troubleshooting](https://github.com/bsojka/bootstrap-buddy/wiki/Troubleshooting) resources.

If you've read those pages and are still having problems, please search our [issues](https://github.com/bsojka/bootstrap-buddy/issues) (both open and closed) to see whether your issue has already been addressed there. If not, you can [open an issue](https://github.com/bsojka/bootstrap-buddy/issues/new?template=default.md).

For a faster and more focused response, be sure to provide the following in your issue:

- Log output (see [wiki](https://github.com/bsojka/bootstrap-buddy/wiki/FAQ#how-do-i-view-bootstrap-buddys-logs) for information on retrieving logs)
- macOS version you're deploying to
- MDM (name and version) you're using
- What troubleshooting steps you've already taken

---

## Contribution

Contributions are welcome! To contribute, [create a fork](https://github.com/bsojka/bootstrap-buddy/fork) of this repository, commit and push changes to a branch of your fork, and then submit a [pull request](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request). Your changes will be reviewed by a project maintainer.

Contributions don't have to be code; we appreciate any help maintaining our [wiki](https://github.com/bsojka/bootstrap-buddy/wiki) or answering [issues](https://github.com/bsojka/bootstrap-buddy/issues).

---

## Credits

Bootstrap Buddy was created by **Apple Business Unit at Inetum Polska Sp. z o.o.**.
It is however entirely based on Escrow Buddy created by the **Netflix Client Systems Engineering** team.

The [Crypt](https://github.com/grahamgilbert/crypt) project was a major inspiration in the creation of Escrow Buddy — huge thanks to Graham, Wes, and the Crypt team! Jeremy Baker and Tom Burgin's 2015 PSU MacAdmins [session](https://www.youtube.com/watch?v=tcmql5byA_I) on authorization plugins was also a valuable resource.

Escrow Buddy is licensed under the [Apache License, version 2.0](https://www.apache.org/licenses/LICENSE-2.0) and so is the Bootstrap Buddy.
