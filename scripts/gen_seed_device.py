# -*- coding: utf-8 -*-
"""从 docs/台账提取.txt 生成 database/seed-device.sql（幂等，可重复执行）。"""
import os
import re

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(BASE, 'docs', '台账提取.txt')
OUT = os.path.join(BASE, 'database', 'seed-device.sql')

MODEL_MAP = {
    'xFace500': 'XF500',
    'xFace600': 'XF600',
    'XF500': 'XF500',
    'XF600': 'XF600',
    'iclock360': 'iClock360',
    'iClock360': 'iClock360',
    'TDB08(PRO）': 'TDB08 PRO',
    'TDB08(PRO)': 'TDB08 PRO',
    'TDB08 PRO': 'TDB08 PRO',
}

# M0 只读探测补充的异常（台账之外的事实）
EXTRA_ABNORMAL = {
    '192.168.12.115': '自报IP(192.168.30.234)与接入IP不一致，待核（M0 探测）',
}

FACTORIES = ['废水站', '老厂', 'C厂', 'E厂', '集团', '新厂']


def esc(s):
    return s.replace("'", "''") if s else s


def main():
    devices = []
    with open(SRC, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\n')
            if not line.strip() or line.startswith(('华新', '厂别', '===', ' ')):
                continue
            cols = [c.strip() for c in line.split('\t')]
            if len(cols) < 6:
                continue
            factory = cols[0]
            if factory not in FACTORIES:
                continue
            name, ip, model, dtype, port = cols[1], cols[2], cols[3], cols[4], cols[5]
            remark = ' '.join(c for c in cols[6:] if c)
            devices.append({
                'factory': factory, 'name': name, 'ip': ip, 'model': model,
                'type': dtype, 'port': port, 'remark': remark,
            })

    lines = []
    lines.append('-- 设备台账种子数据（43 台，来源：华新中控考勤及门禁汇总表.xlsx）')
    lines.append('-- 幂等：以占位 SN（IP-<ip>）为键 UPSERT；真机联调后回填真实 SN/固件/能力档案')
    lines.append('USE hxzk;')
    lines.append('')
    lines.append('-- 厂别作为顶层分组')
    for fac in FACTORIES:
        lines.append(
            "INSERT INTO device_group (name, remark) VALUES ('%s', '台账厂别')"
            " ON DUPLICATE KEY UPDATE remark=VALUES(remark);" % esc(fac)
        )
    lines.append('')
    abnormal_cnt = replace_cnt = 0
    for d in devices:
        model = MODEL_MAP.get(d['model'], d['model'])
        sn = 'IP-' + d['ip']
        abnormal = ''
        needs_replace = 0
        if '需更换' in d['remark']:
            needs_replace = 1
            replace_cnt += 1
        if '暂无法连接' in d['remark'] or needs_replace:
            abnormal = d['remark']
        if d['ip'] in EXTRA_ABNORMAL:
            abnormal = (abnormal + '；' if abnormal else '') + EXTRA_ABNORMAL[d['ip']]
        if abnormal:
            abnormal_cnt += 1
        sql = (
            "INSERT INTO device (sn, name, factory, location, model, device_type, ip, port, "
            "group_id, enabled, abnormal_flag, needs_replace, remark) VALUES ("
            "'%s', '%s', '%s', '%s', '%s', '%s', '%s', %s, "
            "(SELECT id FROM device_group WHERE name='%s'), 1, %s, %d, '%s') "
            "ON DUPLICATE KEY UPDATE name=VALUES(name), factory=VALUES(factory), "
            "model=VALUES(model), device_type=VALUES(device_type), port=VALUES(port), "
            "group_id=VALUES(group_id), abnormal_flag=VALUES(abnormal_flag), "
            "needs_replace=VALUES(needs_replace), remark=VALUES(remark);"
            % (
                esc(sn), esc(d['name']), esc(d['factory']), esc(d['name']),
                esc(model), esc(d['type']), esc(d['ip']), d['port'] or '4370',
                esc(d['factory']),
                ("'%s'" % esc(abnormal)) if abnormal else 'NULL',
                needs_replace,
                esc(d['remark']),
            )
        )
        lines.append(sql)
    lines.append('')

    kao = sum(1 for d in devices if d['type'] == '考勤')
    men = sum(1 for d in devices if d['type'] == '门禁')
    summary = '-- 共 %d 台：考勤 %d + 门禁 %d；需更换 %d 台；异常标记 %d 台\n' % (
        len(devices), kao, men, replace_cnt, abnormal_cnt)
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write(summary)
        f.write('\n'.join(lines))
    print('devices=%d kaoqing=%d menjin=%d abnormal=%d -> %s' % (
        len(devices), kao, men, abnormal_cnt, OUT))


if __name__ == '__main__':
    main()
