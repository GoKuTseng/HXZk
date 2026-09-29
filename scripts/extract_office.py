#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""提取 .xlsx / .docx 内容为 UTF-8 文本（仅标准库，跨机器零依赖）。

用法:
    python extract_office.py xlsx <in.xlsx> <out.txt>
    python extract_office.py docx <in.docx> <out.txt>
"""
import sys
import zipfile
import xml.etree.ElementTree as ET

NS = {
    'a': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main',
    'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
}
R_ID = '{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id'


def xlsx_text(path, out):
    z = zipfile.ZipFile(path)
    shared = []
    if 'xl/sharedStrings.xml' in z.namelist():
        root = ET.fromstring(z.read('xl/sharedStrings.xml'))
        for si in root.findall('a:si', NS):
            shared.append(''.join(t.text or '' for t in si.iter('{%s}t' % NS['a'])))
    wb = ET.fromstring(z.read('xl/workbook.xml'))
    rels = ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))
    relmap = {r.get('Id'): r.get('Target') for r in rels}
    lines = []
    for sheet in wb.find('a:sheets', NS):
        name = sheet.get('name')
        target = relmap[sheet.get(R_ID)].lstrip('/')
        if not target.startswith('xl/'):
            target = 'xl/' + target
        root = ET.fromstring(z.read(target))
        lines.append('=== SHEET: %s ===' % name)
        for row in root.iter('{%s}row' % NS['a']):
            cells = []
            for c in row.iter('{%s}c' % NS['a']):
                t = c.get('t')
                v = c.find('a:v', NS)
                if t == 's':
                    val = shared[int(v.text)] if v is not None and v.text else ''
                elif t == 'inlineStr':
                    val = ''.join(x.text or '' for x in c.iter('{%s}t' % NS['a']))
                else:
                    val = v.text if v is not None and v.text else ''
                cells.append(val)
            if any(x.strip() for x in cells):
                lines.append('\t'.join(cells))
        lines.append('')
    with open(out, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))


def docx_text(path, out):
    z = zipfile.ZipFile(path)
    root = ET.fromstring(z.read('word/document.xml'))
    body = root.find('w:body', NS)
    lines = []
    for el in body:
        tag = el.tag.split('}')[1]
        if tag == 'p':
            txt = ''.join(t.text or '' for t in el.iter('{%s}t' % NS['w']))
            if txt.strip():
                lines.append(txt)
        elif tag == 'tbl':
            lines.append('--- TABLE ---')
            for tr in el.iter('{%s}tr' % NS['w']):
                cells = []
                for tc in tr.iter('{%s}tc' % NS['w']):
                    txt = ''.join(t.text or '' for t in tc.iter('{%s}t' % NS['w']))
                    cells.append(txt.strip())
                lines.append(' | '.join(cells))
            lines.append('--- END TABLE ---')
    with open(out, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))


if __name__ == '__main__':
    kind, src, dst = sys.argv[1], sys.argv[2], sys.argv[3]
    if kind == 'xlsx':
        xlsx_text(src, dst)
    else:
        docx_text(src, dst)
    print('OK -> %s' % dst)
