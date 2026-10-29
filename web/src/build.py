"""Builds web/index.html from the template, the component CSS and the bundled Lucide icons.
Run: python3 web/src/build.py"""
import pathlib
src = pathlib.Path(__file__).parent
html = (src / 'index.template.html').read_text()
html = html.replace('/*PROTO_CSS*/', (src / 'components.css').read_text())
html = html.replace('/*ICONS*/', (src / 'icons.json').read_text())
(src.parent / 'index.html').write_text(html)
print('built', len(html), 'bytes')
