#!/bin/bash
# Makes monochrome images from a grey and a colour picture (true colour and screen
# images, each rendering method, larger sizes), turns them back into true colour and
# screen images with each aspect, scaling, mode and shrink choice, and negates one (the
# MONO, MONOOUT, MONONEG and SAVE MONO test commands), then checks every result against
# test/mono_model.py, SuperConvert's conversions as docs/superconvert-truecolor.md
# describes them.
cd "$(dirname "$0")/.."
[ -d build/fixtures/true ] || python3 -I test/make_true.py build/fixtures/true > /dev/null
python3 -I test/mono_list.py > build/mono.test
COMMANDS=build/mono.test RUN_SECONDS="${RUN_SECONDS:-4000}" DUMP_EVERY=400 ./test/run.sh > /dev/null
python3 -I test/check_mono.py
