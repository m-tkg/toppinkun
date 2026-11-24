# Resources/AppIcon.png を生成する（要 Pillow）。
# 使い方: python3 Scripts/icons/render-appicon.py Resources/AppIcon.png
import sys
from PIL import Image, ImageDraw, ImageFilter
S=4; N=1024*S
def s(v): return int(v*S)
img=Image.new('RGBA',(N,N),(0,0,0,0))

def win(x,y,w,h,body,bar,outline,r=70,shadow=True):
    global img
    if shadow:
        sh=Image.new('RGBA',(N,N),(0,0,0,0)); d=ImageDraw.Draw(sh)
        d.rounded_rectangle([s(x+10),s(y+24),s(x+w+10),s(y+h+24)],radius=s(r),fill=(0,0,0,70))
        sh=sh.filter(ImageFilter.GaussianBlur(s(18))); img=Image.alpha_composite(img,sh)
    d=ImageDraw.Draw(img)
    d.rounded_rectangle([s(x),s(y),s(x+w),s(y+h)],radius=s(r),fill=outline)
    o=14
    d.rounded_rectangle([s(x+o),s(y+o),s(x+w-o),s(y+h-o)],radius=s(r-o),fill=body)
    # title bar
    bar_h=110
    layer=Image.new('RGBA',(N,N),(0,0,0,0)); ld=ImageDraw.Draw(layer)
    ld.rounded_rectangle([s(x+o),s(y+o),s(x+w-o),s(y+h-o)],radius=s(r-o),fill=bar)
    mask=Image.new('L',(N,N),0); ImageDraw.Draw(mask).rectangle([s(x),s(y),s(x+w),s(y+o+bar_h)],fill=255)
    img.paste(layer,(0,0),Image.composite(layer,Image.new('RGBA',(N,N),(0,0,0,0)),mask).split()[3])
    d=ImageDraw.Draw(img)
    for i,c in enumerate([(255,95,87),(254,188,46),(40,200,64)]):
        cx=x+o+60+i*58; cy=y+o+bar_h/2
        d.ellipse([s(cx-20),s(cy-20),s(cx+20),s(cy+20)],fill=c)

# back windows
win(110,330,560,430,(214,220,232,255),(178,188,206,255),(70,78,96,255))
win(200,250,580,450,(226,232,242,255),(190,200,218,255),(70,78,96,255))
# front window
fx,fy,fw,fh=300,360,620,500
win(fx,fy,fw,fh,(255,255,255,255),(66,133,244,255),(40,48,66,255))
d=ImageDraw.Draw(img)
# face
cx=fx+fw/2; cy=fy+300
for ex in (cx-110,cx+110):
    d.ellipse([s(ex-34),s(cy-48),s(ex+34),s(cy+48)],fill=(40,48,66,255))
    d.ellipse([s(ex-14),s(cy-34),s(ex+10),s(cy-10)],fill=(255,255,255,255))
d.arc([s(cx-60),s(cy+20),s(cx+60),s(cy+110)],start=20,end=160,fill=(40,48,66,255),width=s(16))
for bx in (cx-185,cx+185):
    d.ellipse([s(bx-38),s(cy+40),s(bx+38),s(cy+80)],fill=(255,150,170,170))

# pushpin (tilted) at top-right of front window
pin=Image.new('RGBA',(N,N),(0,0,0,0)); pd=ImageDraw.Draw(pin)
px,py=620,250
pd.polygon([(s(px-10),s(py+150)),(s(px+10),s(py+150)),(s(px+2),s(py+260)),(s(px-2),s(py+260))],fill=(150,155,165,255))
pd.rounded_rectangle([s(px-95),s(py+120),s(px+95),s(py+165)],radius=s(20),fill=(200,40,50,255),outline=(40,48,66,255),width=s(12))
pd.polygon([(s(px-55),s(py+130)),(s(px+55),s(py+130)),(s(px+38),s(py+40)),(s(px-38),s(py+40))],fill=(235,64,72,255),outline=(40,48,66,255))
pd.ellipse([s(px-80),s(py-60),s(px+80),s(py+70)],fill=(235,64,72,255),outline=(40,48,66,255),width=s(12))
pd.ellipse([s(px-45),s(py-35),s(px-5),s(py+0)],fill=(255,170,175,255))
pin=pin.rotate(-25,center=(s(px),s(py+250)),resample=Image.BICUBIC)
sh=Image.new('RGBA',(N,N),(0,0,0,0)); sh.paste((0,0,0,90),(0,0),pin.split()[3]); sh=sh.filter(ImageFilter.GaussianBlur(s(10)))
img=Image.alpha_composite(img,sh.transform(sh.size,Image.AFFINE,(1,0,-s(12),0,1,-s(14))))
img=Image.alpha_composite(img,pin)
img=img.resize((1024,1024),Image.LANCZOS)
img.save(sys.argv[1])
