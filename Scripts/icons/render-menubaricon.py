# Resources/MenuBarIcon.png を生成する（要 Pillow）。
# 使い方: python3 Scripts/icons/render-menubaricon.py Resources/MenuBarIcon.png
import sys
from PIL import Image, ImageDraw
S=16; W=50; H=44
def s(v): return int(v*S)
img=Image.new('RGBA',(W*S,H*S),(0,0,0,0)); d=ImageDraw.Draw(img)
K=(0,0,0,255); C=(0,0,0,0)
# back window (outline only, partially)
d.rounded_rectangle([s(2),s(10),s(30),s(34)],radius=s(5),outline=K,width=s(3))
# front window: erase area under it then draw
d.rounded_rectangle([s(9),s(15),s(41),s(42)],radius=s(5),fill=C)
d.rounded_rectangle([s(9),s(15),s(41),s(42)],radius=s(5),outline=K,width=s(3))
d.rectangle([s(9),s(15),s(41),s(22)],fill=K)
d.rounded_rectangle([s(9),s(15),s(41),s(24)],radius=s(5),fill=K)
d.rectangle([s(10.5),s(21),s(39.5),s(24)],fill=K)
# pushpin (tilted), with a transparent gap around it
def pin_mask(grow):
    m=Image.new('L',(W*S,H*S),0); md=ImageDraw.Draw(m)
    cx,top=31,1.5
    g=grow
    md.ellipse([s(cx-5.5-g),s(top-g),s(cx+5.5+g),s(top+9+g)],fill=255)          # head
    md.polygon([(s(cx-3.5-g),s(top+7)),(s(cx+3.5+g),s(top+7)),(s(cx+2.5+g),s(top+12)),(s(cx-2.5-g),s(top+12))],fill=255)  # neck
    md.rounded_rectangle([s(cx-7-g),s(top+11-g),s(cx+7+g),s(top+14.5+g)],radius=s(1.5),fill=255)  # collar
    md.polygon([(s(cx-1.3-g),s(top+14)),(s(cx+1.3+g),s(top+14)),(s(cx+0.3),s(top+21+g)),(s(cx-0.3),s(top+21+g))],fill=255)  # needle
    return m.rotate(-30,center=(s(cx),s(top+21)),resample=Image.BICUBIC)
img.paste(C,(0,0),pin_mask(2.2))
img.paste(K,(0,0),pin_mask(0))
img=img.resize((W*2,H*2),Image.LANCZOS)  # 88px（18pt 表示時に十分な解像度）
img.save(sys.argv[1])
