# Pre-publication review

Reviewed locally on 2026-11-06. This is a source and packaging review, not an independent security or legal certification.

## Privacy

Tracked files and reachable commit history were checked for the known local monitor serial, saved Wi-Fi network name, personal email, home-directory path, private-key headers and common access-token patterns. No such data was found. Logs, EDIDs, build outputs, downloaded kernel trees and backups are ignored and not committed. Commit authorship intentionally uses the public GitHub handle and its no-reply address; publishing under a named account is not anonymous.

## Provenance and scope

See `CREDITS.md` for dependencies and upstream sources. Repository code is marked GPL-2.0-only; downloaded Linux source keeps its own notices and is not included in Git. Public documentation describes limited hardware coverage and AI-assisted development, and does not claim official support, independent certification, or a generic driver repair.

## Test limits

Shell syntax and Python compilation checks passed locally. The GitHub Actions workflow has not run because this repository has not been published. Audit changes were made only to the publication copy, not installed system files. Hardware observations describe the original troubleshooting session; they do not mean every later packaging/error-path change was exercised on hardware.

## Webcam-specific review

The 11 built modules pass the strengthened verifier against the installed kernel. A deliberately changed build-time kernel symbol table was rejected. The verifier now checks the live installed symbol table as well as full module vermagic, structure section size and imported CRCs. These are useful compatibility gates, not proof of all PS5 runtime structure compatibility. Raw upstream kernel source plus a custom kernel configuration is not equivalent to rebuilding the entire custom PS5 source tree. Do not force-load a rejected module.

Original hardware outcome: camera enumerated and the user confirmed the fix worked. Later publication-copy verifier improvements were exercised against the existing build; a fresh download/build and reinstall were not repeated during this review.
