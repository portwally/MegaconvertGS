#!/bin/bash
# The Works of Art loader (docs/superconvert-formats-extra.md 1): the two pages of a test
# file (test/make_woa.py, the documentation's example) loaded as monochrome images, chosen
# with WOAPAGE instead of the page window (the second found by its file type), and three
# damaged copies refused. Checked against a decoder written from the documentation.
cd "$(dirname "$0")/.."
python3 -I test/make_woa.py build/fixtures/woa
COMMANDS=test/woa.test RUN_SECONDS=150 DUMP_EVERY=50 ./test/run.sh > /dev/null
python3 -I test/check_woa.py
