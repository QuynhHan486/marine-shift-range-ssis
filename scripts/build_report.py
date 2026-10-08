"""Render the editable Markdown SSIS chapter as a typeset PDF with actual package diagrams."""
import html
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib import colors
from reportlab.lib.enums import TA_JUSTIFY
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, KeepTogether
from reportlab.graphics.shapes import Drawing, Rect, String, Line, Polygon

ROOT=Path(__file__).resolve().parents[1]
FONT=Path('C:/Windows/Fonts')
for name,file in [('Body','times.ttf'),('Bold','timesbd.ttf'),('Italic','timesi.ttf'),('Code','consola.ttf')]:
    pdfmetrics.registerFont(TTFont(name,str(FONT/file)))
pdfmetrics.registerFontFamily('Body',normal='Body',bold='Bold',italic='Italic',boldItalic='Bold')
styles={
 'body':ParagraphStyle('body',fontName='Body',fontSize=11.5,leading=15.6,spaceAfter=6,alignment=TA_JUSTIFY),
 'title':ParagraphStyle('title',fontName='Bold',fontSize=16,leading=21,spaceAfter=15,keepWithNext=True),
 'h2':ParagraphStyle('h2',fontName='Bold',fontSize=13.5,leading=18,spaceBefore=12,spaceAfter=8,keepWithNext=True),
 'h3':ParagraphStyle('h3',fontName='Bold',fontSize=12,leading=16,spaceBefore=9,spaceAfter=6,keepWithNext=True),
 'table':ParagraphStyle('table',fontName='Body',fontSize=10,leading=13,spaceAfter=0),
 'code':ParagraphStyle('code',fontName='Code',fontSize=8.5,leading=11.5,spaceAfter=1),
 'caption':ParagraphStyle('caption',fontName='Italic',fontSize=10,leading=14,spaceAfter=10,spaceBefore=4),
}

def inline(s):
    s=html.escape(s)
    s=re.sub(r'\[([^\]]+)\]\((https?://[^\s)]+)\)',lambda m:f'<link href="{m[2]}" color="#174d70">{m[1]}</link>',s)
    s=re.sub(r'`([^`]+)`',lambda m:'<font name="Code" size="9">'+m[1]+'</font>',s)
    s=re.sub(r'\*\*([^*]+)\*\*',r'<b>\1</b>',s)
    return s

def diagram():
    ns={'d':'www.microsoft.com/SqlServer/Dts'}
    package=ET.parse(ROOT/'ssis/Package.dtsx').getroot()
    key='{'+ns['d']+'}'
    tasks={x.get(key+'refId'):x.get(key+'ObjectName') for x in package.find('d:Executables',ns)}
    edges={x.get(key+'From'):x.get(key+'To') for x in package.find('d:PrecedenceConstraints',ns)}
    start=next(iter(set(tasks)-set(edges.values())));names=[]
    while start:
        names.append(tasks[start]);start=edges.get(start)
    assert len(names)==11 and names[0]=='SQL Begin Batch' and names[-1]=='SQL Reconcile and Publish'
    d=Drawing(475,286);left=53;width=370;h=18;step=24
    for i,name in enumerate(names):
        y=265-i*step
        d.add(Rect(left,y,width,h,rx=3,ry=3,fillColor=colors.HexColor('#eef5f8' if name.startswith('SQL') else '#edf6f0'),strokeColor=colors.HexColor('#728c99'),strokeWidth=.6))
        d.add(String(left+10,y+5,f'{i+1:02d}  {name}',fontName='Body',fontSize=10,fillColor=colors.black))
        if i<len(names)-1:
            d.add(Line(238,y,238,y-4,strokeColor=colors.HexColor('#617480'),strokeWidth=.8))
            d.add(Polygon([235,y-3,238,y-6,241,y-3],fillColor=colors.HexColor('#617480'),strokeColor=None))
    d.add(String(53,3,'OnError: SQL Record Failure ghi trạng thái FAILED và giải phóng khóa phiên',fontName='Italic',fontSize=9))
    return d

def markdown_table(lines):
    rows=[[c.strip() for c in line.strip().strip('|').split('|')] for line in lines]
    rows.pop(1)
    n=len(rows[0])
    if n==2:widths=[145,330]
    elif n==3:widths=[135,110,230] if 'Biến' in rows[0][0] else [150,163,162]
    elif n==4:widths=[35,175,132,133]
    else:widths=[475/n]*n
    # Four-column control flow has a narrow sequence, name and longer explanation.
    if rows[0][0]=='Thứ tự':widths=[36,160,279]
    data=[[Paragraph(inline(c),styles['table']) for c in row] for row in rows]
    t=Table(data,colWidths=widths,repeatRows=1,hAlign='LEFT')
    t.setStyle(TableStyle([
        ('BACKGROUND',(0,0),(-1,0),colors.HexColor('#eef1f3')),
        ('LINEBELOW',(0,0),(-1,0),.65,colors.HexColor('#607480')),
        ('LINEBELOW',(0,1),(-1,-1),.3,colors.HexColor('#d1d8dc')),
        ('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),6),
        ('RIGHTPADDING',(0,0),(-1,-1),6),('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6)
    ]));return t

def footer(canvas,doc):
    canvas.saveState();canvas.setFont('Body',9);canvas.setFillColor(colors.HexColor('#555555'))
    canvas.drawString(60,32,'MARINE SHIFT RANGE  |  Chương SSIS')
    canvas.drawRightString(A4[0]-60,32,str(doc.page));canvas.restoreState()

def main():
    lines=(ROOT/'docs/CHUONG_2_SSIS.md').read_text(encoding='utf-8').splitlines();story=[];i=0
    while i<len(lines):
        line=lines[i].strip()
        if not line:i+=1;continue
        if line.startswith('```'):
            i+=1;block=[]
            while i<len(lines) and not lines[i].startswith('```'):block.append(lines[i]);i+=1
            items=[Paragraph(html.escape(x).replace(' ','&#160;'),styles['code']) for x in block]
            story.append(KeepTogether([Spacer(1,4)]+items+[Spacer(1,8)]));i+=1;continue
        if line.startswith('|'):
            block=[]
            while i<len(lines) and lines[i].strip().startswith('|'):block.append(lines[i]);i+=1
            story.extend([markdown_table(block),Spacer(1,10)]);continue
        if line.startswith('# '):story.append(Paragraph(inline(line[2:]),styles['title']))
        elif line.startswith('## '):
            story.append(Paragraph(inline(line[3:]),styles['h2']))
            if line.startswith('## 2.3'):
                story.append(diagram());story.append(Paragraph('Hình 2.1 Sơ đồ Control Flow dựng từ cấu trúc Package.dtsx đã chạy thành công',styles['caption']))
        elif line.startswith('### '):story.append(Paragraph(inline(line[4:]),styles['h3']))
        elif line.startswith('- '):story.append(Paragraph('• '+inline(line[2:]),styles['body']))
        else:
            block=[line]
            while i+1<len(lines) and lines[i+1].strip() and not lines[i+1].startswith(('#','|','```','- ')):
                i+=1;block.append(lines[i].strip())
            paragraph=Paragraph(inline(' '.join(block)),styles['body'])
            if i+1<len(lines) and lines[i+1].lstrip().startswith('|'):paragraph.keepWithNext=True
            if line.startswith('**Bước') and line.endswith(':'):paragraph.keepWithNext=True
            story.append(paragraph)
        i+=1
    doc=SimpleDocTemplate(str(ROOT/'docs/CHUONG_2_SSIS.pdf'),pagesize=A4,rightMargin=60,leftMargin=60,topMargin=53,bottomMargin=55,
        title='Chương 2 Tích hợp dữ liệu sinh vật biển bằng SSIS',author='Marine Shift Range project')
    doc.build(story,onFirstPage=footer,onLaterPages=footer)
    print('Created docs/CHUONG_2_SSIS.pdf')

if __name__=='__main__':main()
