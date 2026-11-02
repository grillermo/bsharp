#!/usr/bin/env python3
"""Writes App/Assets.xcassets/snake-<piece>.imageset for the streak snake's four pieces.

Each piece is drawn heading right with its back on top, 100 units thick, and each joint falls in
the middle of a green band, so they connect in any order. The sizes here must match SnakeLayout in
ElisaKit. Redrawn from Reference Material/snake/snakes-traced.svg. Run it again only if a piece
changes; the imagesets are committed.
"""
import json
import math
from pathlib import Path

ASSETS = Path(__file__).resolve().parents[1] / "App" / "Assets.xcassets"

GREEN,LGREEN,PURPLE,LPURPLE='#84f494','#ccf4a8','#8864e0','#c080ec'
PINK,TEAL,INDIGO,MAGENTA='#fca8d0','#40a080','#4048a4','#c068b8'
T=100; LW=5; HI=31; BELLY=72; PERIOD=200; R=180  # thickness, line, highlight/belly rows, tile, corner
BOW=9
def f(v):
    s=f'{v:.2f}'.rstrip('0').rstrip('.')
    return '0' if s=='-0' else s
def spline(pts,move=True):
    """Catmull-Rom through pts as cubic Beziers."""
    d=f'M{f(pts[0][0])} {f(pts[0][1])}' if move else f'L{f(pts[0][0])} {f(pts[0][1])}'
    for i in range(len(pts)-1):
        p0=pts[max(i-1,0)];p1=pts[i];p2=pts[i+1];p3=pts[min(i+2,len(pts)-1)]
        c1=(p1[0]+(p2[0]-p0[0])/6,p1[1]+(p2[1]-p0[1])/6); c2=(p2[0]-(p3[0]-p1[0])/6,p2[1]-(p3[1]-p1[1])/6)
        d+=f'C{f(c1[0])} {f(c1[1])} {f(c2[0])} {f(c2[1])} {f(p2[0])} {f(p2[1])}'
    return d
def closed(*spans):
    d=''
    for i,s in enumerate(spans): d+=spline(s,move=i==0)
    return d+'Z'
def fill(d,c): return f'<path fill="{c}" d="{d}"/>'
def line(d,c,w=LW,cap='butt'): return f'<path fill="none" stroke="{c}" stroke-width="{w}" stroke-linecap="{cap}" stroke-linejoin="round" d="{d}"/>'
def lin(a,b,n=8): return [(a[0]+(b[0]-a[0])*i/n,a[1]+(b[1]-a[1])*i/n) for i in range(n+1)]
def divider_x(x,y): return x+BOW*(1-((y-BELLY/2)/(BELLY/2))**2)   # bows towards the head
def strip(M,x0=0,x1=PERIOD):
    """The body between x0 and x1 (bands repeat green, purple, green), through mapping M."""
    def span(a,b,n=10): return [M(*p) for p in lin(a,b,n)]
    out=[]; bands=[]
    # Bands in tile coordinates: dividers at 50 and 150, repeating every PERIOD.
    k=math.floor((x0-50)/PERIOD); edges=[x0]
    e=50+k*PERIOD
    while e<x1:
        if e>x0: edges.append(e)
        e+=100
    edges.append(x1)
    def isdiv(x): return ((x-50)%100)==0
    def row(xa,xb,y,bow=True):
        n=max(4,int((xb-xa)/10))
        return [(xa+(xb-xa)*i/n,y) for i in range(n+1)]
    def dx(x,y): return divider_x(x,y) if isdiv(x) else x
    for a,b in zip(edges,edges[1:]):
        mid=(a+b)/2; green=((mid-50)%200)>=100
        main,hi,edge=(GREEN,LGREEN,TEAL) if green else (PURPLE,LPURPLE,INDIGO)
        # Whole band, belly rows overlapped so no background shows between shapes.
        top=dx(a,0),dx(b,0)
        left=[(dx(a,y),y) for y in range(0,BELLY+1,8)]; right=[(dx(b,y),y) for y in range(BELLY,-1,-8)]
        poly=[left,lin((left[-1][0],BELLY+2),(right[0][0],BELLY+2)),right,lin((right[-1][0],0),(left[0][0],0))]
        out.append(fill(closed(*[[M(*p) for p in s] for s in poly]),main))
        # Back highlight, its lower edge a low wave that meets the next band.
        def h(x): return HI+2.2*math.sin(2*math.pi*x/PERIOD)
        hl=[(dx(a,y),y) for y in range(0,int(HI)+1,8)]; hb=[(x,h(x)) for x,_ in row(dx(a,HI),dx(b,HI),0)]
        hr=[(dx(b,y),y) for y in range(int(HI),-1,-8)]
        out.append(fill(closed(*[[M(*p) for p in s] for s in [hl,hb,hr,lin((hr[-1][0],0),(hl[0][0],0))]]),hi))
        out.append(('edge',row(a,b,LW/2),edge))
    # Belly: unbroken pink.
    belly=[lin((x0,BELLY),(x1,BELLY),20),lin((x1,BELLY),(x1,T),2),lin((x1,T),(x0,T),20),lin((x0,T),(x0,BELLY),2)]
    res=[o for o in out if isinstance(o,str)]
    res.append(fill(closed(*[[M(*p) for p in s] for s in belly]),PINK))
    res.append(line(spline([M(*p) for p in lin((x0,BELLY),(x1,BELLY),20)]),MAGENTA,4))
    res.append(line(spline([M(*p) for p in lin((x0,T-LW/2),(x1,T-LW/2),20)]),MAGENTA))
    for o in out:
        if isinstance(o,tuple):
            res.append(line(spline([M(*p) for p in o[1]]),o[2]))
    for e in edges:
        if isdiv(e):
            res.append(line(spline([M(divider_x(e,y),y) for y in range(0,BELLY+1,8)]),INDIGO,4))
    return res
def svg(w,h,body,title):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {f(w)} {f(h)}" width="{f(w)}" height="{f(h)}"><title>{title}</title>\n'+'\n'.join(body)+'\n</svg>\n'
def segment(): return svg(PERIOD,T,strip(lambda x,y:(x,y)),'Snake segment: tile along x')
def corner():
    def M(x,y):
        a=x/PERIOD*math.pi/2; r=R-y
        return (r*math.sin(a),R-r*math.cos(a))
    return svg(R,R,strip(M),'Snake corner: enters left, leaves bottom')
def tail():
    W=250; J=W-50  # J: the divider where the tile's green half starts
    # Tip to the right edge. Back and belly edges taper to a blunt point.
    X0,TIP,L=7,62,193
    def g(x):
        t=min(max((x-X0)/L,0),1); return (1-(1-t)**2.2)**.6
    def yt(x): return TIP-(TIP-2.5)*g(x)
    def yb(x): return TIP+(97.5-TIP)*g(x)
    xs=[X0,7.5,8.5,10,13,18,26,38,55,75,100,130,160,185,200,W]
    sil=closed([(x,yt(x)) for x in xs],[(W,97.5)],[(x,yb(x)) for x in xs[::-1]])
    b=[fill(sil,GREEN)]
    def dv(x):  # divider following the taper, bowed to the head
        ya,yc=yt(x),yb(x); return [(x+BOW*(1-((t-.5)/.5)**2),ya+(yc-ya)*t) for t in [i/8 for i in range(9)]]
    d1=dv(95); d2=dv(J)
    # purple band between dividers
    pur=closed(d1,[(d2[-1][0],yb(d2[-1][0]))],d2[::-1],[(d1[0][0],d1[0][1])])
    b.append(fill(pur,PURPLE))
    # back highlights
    def hl(x0,x1,c,frac=.33):
        ts=[x0+(x1-x0)*i/10 for i in range(11)]
        low=[(x,yt(x)+(yb(x)-yt(x))*frac+2.2*math.sin(2*math.pi*(x-W)/PERIOD)) for x in ts]
        up=[(x,yt(x)) for x in ts[::-1]]
        return fill(closed(low,up),c)
    b.append(hl(95+BOW*.8,J+BOW*.6,LPURPLE))
    b.append(hl(J+BOW*.6,W,LGREEN))
    b.append(hl(30,95+BOW*.6,LGREEN,.3))
    # pink belly: tapers away before the tip
    px=[W,220,190,160,130,105]; bb=[(x,yb(x)) for x in px]
    by=[(x,yb(x)-(yb(x)-(yb(x)-25.5))*(x-105)/(W-105)) for x in px]
    b.append(fill(closed(bb,by[::-1]),PINK))
    b.append(line(spline(by),MAGENTA,4))
    # outlines
    b.append(line(spline([(x,yb(x)) for x in px]),MAGENTA))
    b.append(line(spline([(x,yb(x)) for x in (105,75,55,38,26,18,13,10,8.5,7.5,X0)]),TEAL))
    b.append(line(spline([(x,yt(x)) for x in (X0,7.5,8.5,10,13,18,26,38,55,75,95)]),TEAL))
    b.append(line(spline([(x,yt(x)) for x in (95,120,160,J)]),INDIGO))
    b.append(line(spline([(x,yt(x)) for x in (J,225,W)]),TEAL))
    for d in (d1,d2):
        p=[q for q in d if q[1]<=yb(q[0])-(25.5*(q[0]-105)/(W-105))+1] if d is d2 else d
        b.append(line(spline(p),INDIGO,4))
    return svg(W,T,b,'Snake tail: right edge joins a segment')
def head():
    W,H=272,126
    sil=closed([(0,2.5),(35,2.5),(70,2),(102,5),(130,18),(150,34),(170,37),(192,48),(207,70),(203,92),(182,110),(150,120),(105,123.5),(62,121),(32,108),(14,99),(0,97.5)])
    b=[]
    # Tongue goes first, under the lip.
    tongue=closed([(190,92),(214,93),(236,90),(256,86),(268,84)],[(262,92),(268,104)],[(248,101),(228,105),(205,107),(188,106)],[(190,92)])
    b.append(line(tongue,'#b84074',5)); b.append(fill(tongue,'#fc645c'))
    b.append(fill(closed([(190,94),(212,95)],[(214,105)],[(190,106)],[(190,94)]),'#e8385c'))
    b.append(fill(sil,GREEN))
    # Crown highlight, continuing the body's back band.
    b.append(fill(closed([(0,5),(40,5),(70,4.5),(101,7.5),(125,20)],[(112,31),(80,33),(40,32),(0,31)],[(0,5)]),LGREEN))
    # Snout highlight.
    b.append(fill(closed([(170,41),(188,51),(198,66),(186,68),(170,58),(166,46),(170,41)]),LGREEN))
    # Pink belly ends in a curve at the neck.
    nb=closed([(0,72),(26,72),(40,78),(46,92),(42,114.5)],[(30,108),(14,99),(0,97.5)],[(0,72)])
    b.append(fill(nb,PINK))
    b.append(line(spline([(0,72),(26,72),(40,78),(46,92),(42,114.5)]),MAGENTA,4))
    b.append(line(spline([(0,97.5),(14,99),(32,108),(42,114.5)]),MAGENTA))
    b.append(line(spline([(42,114.5),(62,121),(105,123.5),(150,120),(182,110),(203,92),(207,70),(192,48),(170,37),(150,34),(130,18),(102,5),(70,2),(35,2.5),(0,2.5)]),TEAL))
    # Smile and cheek.
    b.append(line(spline([(200,94),(180,105),(158,106),(138,96)]),'#1c4c64',4,'round'))
    b.append(line(spline([(146,91),(138,96),(131,104)]),'#1c4c64',4,'round'))
    # Eye.
    b.append('<ellipse cx="118" cy="50" rx="21" ry="25" fill="#ffffff" stroke="#acbcb4" stroke-width="5"/>')
    b.append('<ellipse cx="125" cy="52" rx="12" ry="17" fill="#2c4464" stroke="#000000" stroke-width="2.5"/>')
    return svg(W,H,b,'Snake head: left edge joins a segment')
for name, draw in dict(segment=segment, corner=corner, tail=tail, head=head).items():
    folder = ASSETS / f"snake-{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / f"snake-{name}.svg").write_text(draw())
    (folder / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"snake-{name}.svg", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True, "template-rendering-intent": "original"},
    }, indent=2) + "\n")

print(f"4 imagesets in {ASSETS}")
