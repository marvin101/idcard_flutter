import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:idcard_flutter/models/api_student.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/models/design_bindings.dart';
import 'package:idcard_flutter/models/design_render_scene.dart';
import 'package:idcard_flutter/models/design_text_layout.dart';
import 'package:idcard_flutter/models/school_profile.dart';
import 'package:idcard_flutter/models/student_field.dart';
import 'package:idcard_flutter/services/design_fonts.dart';
import 'package:idcard_flutter/services/pdf_document_renderer.dart';
import 'package:idcard_flutter/services/pdf_service.dart';
import 'package:idcard_flutter/widgets/design_document_view.dart';

const student = ApiStudent(uuid:'fixture',sessionUuid:'s',classUuid:'c',sectionUuid:'a',
  admissionNo:'ADM-2026-123',fullName:'Élodie D’Souza – Hernández',isActive:true,
  bloodGroup:'B+',photoPath:'photo.png',customFields:[StudentCustomFieldValue(fieldUuid:'house',value:'Blue')]);
const school = SchoolProfile(uuid:'school',schoolCode:'SCH',schoolName:'École International',
  address:'12 School Road\nRanchi, Jharkhand',logoUrl:'logo.png',isActive:true);
const bindings=DesignBindings(student:student,schoolProfile:school,sessionName:'2026–2027',className:'XII',sectionName:'A');

DesignDocument fixture(double width,double height,{bool images=true}) {
  DesignElement text(String id,double y,String field,{double? x,double? w,int weight=400,String align='left',bool static=false}) =>
    DesignElement(id:id,type:static?DesignElementType.text:DesignElementType.boundText,
      x:x??3,y:y,width:w??width-6,height:8,zIndex:2,
      data:static?{'text':field}:{'field':field},style:{'font_size':2.6,'font_weight':weight,'alignment':align,'max_lines':2,'color':'#CC142850'});
  return DesignDocument(canvas:DesignCanvas(width:width,height:height,
    backgroundColor:'#FFF6D8',backgroundImage:images?'background.png':null),elements:[
    DesignElement(id:'header',type:DesignElementType.rectangle,x:0,y:0,width:width,height:12,
      style:{'fill_color':'#803B82F6','border_color':'#A0242C61','border_width':.5,'corner_radius':2}),
    DesignElement(id:'footer',type:DesignElementType.rectangle,x:0,y:height-7,width:width,height:7,
      style:{'fill_color':'#B03B82F6','corner_radius':2}),
    text('school',1,'school_name',weight:900,align:'center'),
    text('address',10,'school_address',weight:400,align:'center'),
    text('name',20,'full_name',weight:700),
    text('admission',29,'admission_no',weight:600,align:'right'),
    text('blood',height-17,'blood_group',w:12),
    text('academic',height-17,'class',x:18,w:10,weight:500),
    text('unicode',height-8,'Café • “ID”',weight:300,align:'center',static:true),
    DesignElement(id:'custom',type:DesignElementType.customFieldText,x:width-20,y:height-17,width:16,height:5,
      data:{'field_uuid':'house'},style:{'font_size':2.6}),
    DesignElement(id:'photo',type:DesignElementType.studentPhoto,x:3,y:38,width:12,height:13,
      style:{'fit':'cover','border_color':'#AA242C61','border_width':.6,'corner_radius':2}),
    DesignElement(id:'logo',type:DesignElementType.schoolLogo,x:width-15,y:38,width:12,height:13,
      style:{'fit':'contain','border_color':'#242C61','border_width':.4,'corner_radius':2}),
    DesignElement(id:'line',type:DesignElementType.line,x:18,y:40,width:width-36,height:2,
      rotation:25,style:{'color':'#D04080','border_width':.5}),
    text('hidden',1,'Hidden content',static:true).copyWith(visible:false),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(()=>DesignFonts.load());
  test('shared scene resolves all binding families, visibility and paint units',() {
    final doc=fixture(53.98,85.6);
    final scene=DesignRenderScene(document:doc,bindings:bindings,assetBaseUrl:'https://school.test/');
    expect(scene.elements.any((n)=>n.element.id=='hidden'),false);
    DesignRenderElement node(String id)=>scene.elements.firstWhere((n)=>n.element.id==id);
    expect(node('school').text,school.schoolName); expect(node('name').text,student.fullName);
    expect(node('address').text,school.address); expect(node('custom').text,'Blue');
    expect(node('academic').text,'XII'); expect(node('unicode').text,'Café • “ID”');
    expect(node('photo').imageUrl,'https://school.test/photo.png');
    expect(node('logo').imageUrl,'https://school.test/logo.png');
    expect(scene.backgroundImage,'https://school.test/background.png');
    expect(node('header').style.fill.a,closeTo(128/255,1e-9));
    expect(node('header').style.borderWidth,.5); expect(node('header').style.radius,2);
    expect(PdfDocumentRenderer.rotation(node('line')),-node('line').radians);
    for(final n in scene.elements) {
      expect(identical(n.element,doc.elements.firstWhere((e)=>e.id==n.element.id)),true);
    }
    for(final weight in DesignFonts.names.keys) {
      expect(DesignRenderStyle(doc.elements.first.copyWith(style:{'font_weight':weight})).weight,weight);
    }
  });

  test('PDF line layout preserves explicit newlines, long values and baselines',() {
    for(final align in ['left','center','right']) {
      final element=DesignElement(id:'text',type:DesignElementType.text,x:2,y:3,width:28,height:20,
        data:{'text':'Élodie Hernández\nCafé – ID'},style:{'font_size':3,'alignment':align,'max_lines':3});
      final node=DesignRenderElement(element,element.data['text'] as String,null);
      final lines=layoutDesignText(node);
      expect(lines.length,greaterThanOrEqualTo(2));
      expect(lines.map((l)=>l.text).join(' '),contains('Café – ID'));
      for(var i=1;i<lines.length;i++) { expect(lines[i].baseline-lines[i-1].baseline,closeTo(3,.05)); }
      expect(lines.every((l)=>l.x>=0),true);
      final long=DesignRenderElement(element.copyWith(width:12),'ABCDEFGHIJKLMNOPQRSTUVWXYZ',null);
      expect(layoutDesignText(long).length,greaterThan(1));
    }
  });

  test('unsupported Devanagari fails explicitly instead of exporting unshaped names',() async {
    expect(()=>DesignFonts.validatePdfText('विद्यालय विद्यार्थी'),throwsUnsupportedError);
    expect(()=>DesignFonts.validatePdfText('Élodie • São Paulo – “ID”'),returnsNormally);
    final doc=fixture(53.98,85.6,images:false);
    final hindi=doc.copyWith(elements:[DesignElement(id:'hindi',type:DesignElementType.text,x:1,y:1,width:40,height:10,data:{'text':'विद्यालय'})]);
    await expectLater(PdfService.generateStudentCard(student:student,schoolName:'School',template:CardTemplate(name:'Hindi',document:hindi)),throwsUnsupportedError);
  });

  for(final size in [const Size(53.98,85.6),const Size(85.6,53.98),const Size(100,100)]) {
    testWidgets('vector PDF fixture ${size.width} x ${size.height} and Flutter baseline parity',(t) async {
      final doc=fixture(size.width,size.height,images:false);
      final scene=DesignRenderScene(document:doc,bindings:bindings);
      debugPrint('fixture: font start'); final fonts=(await t.runAsync(()=>DesignFonts.pdfFonts()))!; debugPrint('fixture: fonts ready');
      final image=img.Image(width:60,height:30);
      for(var x=0;x<60;x++) { for(var y=0;y<30;y++) {image.setPixelRgb(x,y,x<30?230:20,x<30?30:160,80);} }
      final raw=img.encodePng(image);
      final memory=pw.MemoryImage(raw);
      debugNetworkImageHttpClientProvider=()=>_ImageClient(raw);
      addTearDown(()=>debugNetworkImageHttpClientProvider=null);
      final pdf=pw.Document(compress:false);
      final renderer=PdfDocumentRenderer(fonts,{'photo.png':memory,'logo.png':memory});
      pdf.addPage(pw.Page(pageFormat:PdfPageFormat(size.width*PdfPageFormat.mm,size.height*PdfPageFormat.mm),
        margin:pw.EdgeInsets.zero,build:(_)=>renderer.build(scene)));
      debugPrint('fixture: save start'); final bytes=(await t.runAsync(()=>pdf.save()))!; debugPrint('fixture: saved');
      final source=latin1.decode(bytes);
      expect(source.contains('/FontFile2'),true); expect(source.contains('/ToUnicode'),true);
      expect(source.contains('/ca 0.8'),true); expect(source.contains('/BaseFont /Helvetica'),false);
      await t.binding.setSurfaceSize(Size(size.width*6,size.height*6));
      addTearDown(()=>t.binding.setSurfaceSize(null));
      final boundary=GlobalKey();
      await t.pumpWidget(MaterialApp(home:Center(child:RepaintBoundary(key:boundary,
        child:DesignDocumentView(document:doc,student:student,schoolProfile:school,className:'XII')))));
      await t.pumpAndSettle(); debugPrint('fixture: pumped');
      for(final node in scene.elements.where((n)=>n.element.id=='name'||n.element.id=='address')) {
        final text=find.text(node.text);
        final paragraph=t.renderObject<RenderParagraph>(text);
        final origin=t.getTopLeft(find.byKey(ValueKey(node.element.id)));
        final rect=t.getTopLeft(text);
        final lines=layoutDesignText(node);
        expect(lines.first.baseline,closeTo((rect.dy-origin.dy+paragraph.getDistanceToBaseline(TextBaseline.alphabetic)!)/6,.002));
      }
      final out=Platform.environment['PDF_FIXTURE_OUTPUT'];
      if(out!=null) {
        final prefix='$out/${size.width}x${size.height}';
        await t.runAsync(() async {
          await Directory(out).create(recursive:true);
          await File('$prefix.pdf').writeAsBytes(bytes);
          final raster=await (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio:1);
          final png=await raster.toByteData(format:ui.ImageByteFormat.png);
          await File('$prefix-flutter.png').writeAsBytes(png!.buffer.asUint8List()); raster.dispose();
        });
      }
      expect(t.takeException(),isNull);
    });
  }
}

class _ImageClient implements HttpClient {
  _ImageClient(this.bytes);
  final List<int> bytes;
  @override Future<HttpClientRequest> getUrl(Uri url) async => _ImageRequest(bytes);
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class _ImageRequest implements HttpClientRequest {
  _ImageRequest(this.bytes);
  final List<int> bytes;
  @override Future<HttpClientResponse> close() async => _ImageResponse(bytes);
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  _ImageResponse(this.bytes);
  final List<int> bytes;
  @override int get statusCode => 200;
  @override int get contentLength => bytes.length;
  @override HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;
  @override StreamSubscription<List<int>> listen(void Function(List<int>)? onData,{Function? onError,void Function()? onDone,bool? cancelOnError}) =>
    Stream.value(bytes).listen(onData,onError:onError,onDone:onDone,cancelOnError:cancelOnError);
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
