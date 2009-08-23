/*
   Title: Font.hx
      Font import module for importing TrueType fonts.

   Section: ttf
      Imports specified glyphs (character drawings) from a TrueType font file as DefineFont2 swf tag.

   Mandatory attributes:
      import - Path to the file to be imported.
      name - Font name. You can access the imported font with this name from AS3 for example.

   Optional attributes:
      language - (_none_, latin, japanese, korean, simpleChinese, traditionalChinese)
         Language code to include in font definition.

   Child nodes:
      <ttf>'s child nodes specify which characters to import from the font file. If <ttf> doesn't have
      any child nodes then every character which appear in the file are imported.

   Group: include
      Specifies a character set or character range to include.

   Optional attributes:
      range - Range of characters in the form: *firstCharacter..lastCharacter*
      characters - Individual characters in arbitrary order

   Group: exclude
      Specifies a character set or character range to exclude.

   Optional attributes:
      range - Range of characters in the form: *firstCharacter..lastCharacter*
      characters - Individual characters in arbitrary order

   Example:
      Assuming that Font import module is assigned to namespace _font_ the following snippet imports
      the even numbers and the letters _abxyz_ from _arial.ttf_ and names the font _Arial_.
     
      (code)
      <font:ttf import="arial.ttf" name="Arial">
         <include range="0..9"/>
         <exclude characters="13579"/>
         <include characters="abxyz"/>
      </font>
      (end)
*/

import haxe.xml.Check;
import neko.io.File;
import format.swf.Data;
import SamHaXeModule;
import Helpers;
import ModuleService;

typedef NativeKerningData = {
   var left_glyph: Int;
   var right_glyph: Int;
   var x: Int;
   var y: Int;
}

typedef NativeGlyphData = {
   var char_code: Int;
   var advance: Int;
   var min_x: Int;
   var max_x: Int;
   var min_y: Int;
   var max_y: Int;
   var points: Array<Int>;
}

typedef NativeFontData = {
   var has_kerning: Bool;
   var is_fixed_width: Bool;
   var has_glyph_names: Bool;
   var is_italic: Bool;
   var is_bold: Bool;
   var num_glyphs: Int;
   var family_name: String;
   var style_name: String;
   var em_size: Int;
   var ascend: Int;
   var descend: Int;
   var height: Int;
   var glyphs: Array<NativeGlyphData>;
   var kerning: Array<NativeKerningData>;
}

class Font {
   static var interface_versions = ["1.0.0"];
   
   static var description_font: String = "Font import module // (c) 2009 Mindless Labs";
   
   var moduleService_1_0 : ModuleService_1_0;

   public function new() {
   }
   
   public function check_font_1_0(font: NsFastXml): Void {
      var ns = font.ns + ":";

      var font_rule = RNode(ns + "ttf", [
            // Root node attributes
            Att("import"),
            Att("name"),

            Att("language", FEnum(["none", "latin", "japanese", "korean", "simpleChinese", "traditionalChinese"]), "none"),
         ],

         // Child nodes
         ROptional(RNode(ns + "characters", null,
            RMulti(RChoice([
               RNode(ns + "include", [
                  Att("range", FReg(~/^.\.\..$/), ""),
                  Att("characters", null, "")
               ]),
               RNode(ns + "exclude", [
                  Att("range", FReg(~/^.\.\..$/), ""),
                  Att("characters", null, "")
               ])
            ]))
         ))
      );

      haxe.xml.Check.checkNode(font.x, font_rule);
   }
   
   public function import_font_1_0(font_node: NsFastXml, options: Hash<String>): Array<SWFTag> {
      var swf_ver = moduleService_1_0.getFlashVersion();
      if(swf_ver < 3)
         throw "The minimum flash version for dynamic glyph text is 3!";

      var import_font_fn = neko.Lib.load("font", "import_font", 3);
      var font_file = font_node.x.get("import");
      var font_name = font_node.att.name;
      
      var swf_em: Int = if(swf_ver < 9) 1024 else 1024 * 20;
      var font: NativeFontData = null;
      
      try {
         font = neko.Lib.nekoToHaxe(import_font_fn(
            untyped font_file.__s,
            if(font_node.hasLNode.characters) neko.Lib.haxeToNeko(build_charcode_vector(font_node)) else null,
            swf_em
         ));
      }
      catch (e : Dynamic) {
         throw "Could not open file '" + font_file + "', reason:\n" + Helpers.tabbed(e.toString());
      }

      var glyphs = new Array<Font2GlyphData>();
      var glyph_layout = new Array<FontLayoutGlyphData>();

      for(native_glyph in font.glyphs) {
         var shapeRecords = new Array<ShapeRecord>();
         var i: Int = 0;
         var styleChanged: Bool = false;

         while(i < native_glyph.points.length) {
            var type = native_glyph.points[i++];
            switch(type) {
               case 1: // Move
                  var dx = native_glyph.points[i++];
                  var dy = native_glyph.points[i++];
                  shapeRecords.push( SHRChange({
                     moveTo: {dx: dx, dy: -dy},
                     // Set fill style to 1 in first style change record
                     // Required by DefineFontX
                     fillStyle0: if(!styleChanged) {idx: 1} else null,
                     fillStyle1: null,
                     lineStyle:  null,
                     newStyles:  null
                  }));
                  styleChanged = true;

               case 2: // LineTo
                  var dx = native_glyph.points[i++];
                  var dy = native_glyph.points[i++];
                  shapeRecords.push( SHREdge(dx, -dy) );

               case 3: // CurveTo
                  var cdx = native_glyph.points[i++];
                  var cdy = native_glyph.points[i++];
                  var adx = native_glyph.points[i++];
                  var ady = native_glyph.points[i++];
                  shapeRecords.push( SHRCurvedEdge(cdx, -cdy, adx, -ady) );

               default:
                  throw "Invalid control point type encountered! ("+type+")";
            }
         }
         
         shapeRecords.push( SHREnd );

         glyphs.push({
            charCode: native_glyph.char_code,
            shape: {
               shapeRecords: shapeRecords
            } 
         });

         glyph_layout.push({
            advance: native_glyph.advance,
            bounds: {
               left:    native_glyph.min_x,
               right:   native_glyph.max_x,
               top:    -native_glyph.max_y,
               bottom: -native_glyph.min_y,
            }
         });
      }

      var kerning = new Array<FontKerningData>();
      if(font.has_kerning) {
         for(k in font.kerning)
            kerning.push({
               charCode1:  k.left_glyph,
               charCode2:  k.right_glyph,
               adjust:     k.x,
            });
      }
      
      moduleService_1_0.getDependencyRegistry().addFilePath(font_node.x.get("import"));

      var id = moduleService_1_0.getIdRegistry().getNewId();

      var ascent = Math.ceil(font.ascend * swf_em / font.em_size);
      var descent = -Math.ceil(font.descend * swf_em / font.em_size);
      var leading = Math.ceil((font.height - font.ascend + font.descend) * swf_em / font.em_size);

      var language = switch(font_node.att.language) {
         case "none":
            LangCode.LCNone;

         case "latin":
            LangCode.LCLatin;

         case "japanese":
            LangCode.LCLatin;

         case "korean":
            LangCode.LCLatin;

         case "simpleChinese":
            LangCode.LCLatin;

         case "traditionalChinese":
            LangCode.LCLatin;

         default:
            LangCode.LCNone;
      };

      return [
         if(swf_ver < 9)
            // DefineFont2 (always use wide char codes)
            TFont(id, FDFont2(true, {
                  shiftJIS:   false,
                  isSmall:    false,
                  isANSI:     false,
                  isItalic:   font.is_italic,
                  isBold:     font.is_bold,
                  language:   language,
                  name:       font_name,
                  glyphs:     glyphs,
                  layout: {
                     ascent:     ascent,
                     descent:    descent,
                     leading:    leading,
                     glyphs:     glyph_layout,
                     kerning:    kerning
                  }
            }))
         else
            // DefineFont3
            TFont(id, FDFont3({
                  shiftJIS:   false,
                  isSmall:    false,
                  isANSI:     false,
                  isItalic:   font.is_italic,
                  isBold:     font.is_bold,
                  language:   language,
                  name:       font_name,
                  glyphs:     glyphs,
                  layout: {
                     ascent:     ascent,
                     descent:    descent,
                     leading:    leading,
                     glyphs:     glyph_layout,
                     kerning:    kerning
                  }
            }))
      ];
   }

   
   public function help_font_1_0(): String {
      return
'Available XML tags:
  <ttf>: Imports specified glyphs (character drawings) from a TrueType font file as DefineFont2 swf tag.

  Mandatory attributes:
    import - Path to the file to be imported.
    name   - Font name. You can access the imported font with this name from AS3 for example.

  Optional attributes:
    language - Language code to include in font definition.
      - none (default)
      - latin
      - japanese
      - korean
      - simpleChinese
      - traditionalChinese

  Child nodes:
    <ttf> child nodes specify which characters to import from the font file. If <ttf> does not have
    any child nodes then every character which appear in the file are imported.

    <include>: Specifies a character set or character range to include.

    Optional attributes:
      range      - Range of characters in the form: firstCharacter..lastCharacter
      characters - Individual characters in arbitrary order

     <exclude>: Specifies a character set or character range to exclude.

     Optional attributes:
       range      - Range of characters in the form: firstCharacter..lastCharacter
       characters - Individual characters in arbitrary order

  Example:
    Assuming that Font import module is assigned to namespace _font_ the following snippet imports
    the even numbers and the letters _abxyz_ from _arial.ttf_ and names the font _Arial_.
     
      <font:ttf import="arial.ttf" name="Arial">
         <include range="0..9"/>
         <exclude characters="13579"/>
         <include characters="abxyz"/>
      </font>';
   }
   
   function build_charcode_vector(font: NsFastXml): Array<Int> {
      var h = new IntHash<Bool>();
      for(n in font.lnode.characters.elements) {
         var set: Bool = (n.lname == "include");
         
         if(n.has.range && n.att.range.length > 0) {
            var from_char = n.att.range.charCodeAt(0);
            var to_char = n.att.range.charCodeAt(3);
            for(i in from_char...to_char+1) {
               h.set(i, set);
            }
         }

         if(n.has.characters && n.att.characters.length > 0) {
            var s = n.att.characters;
            for(i in 0...s.length) {
               h.set(s.charCodeAt(i), set);
            }
         }
      }

      var v = new Array<Int>();
      for(ch in h.keys())
         if(h.get(ch))
            v.push(ch);

      v.sort(Reflect.compare);

      return v;
   }

   public static function initModule(): Bool {
      return true;
   }
   
   public static function initInterface(version: String, moduleService : Dynamic): Void {
      
      var lm = neko.vm.Module.local();
      switch(version) {
         case "1.0.0":
            var module = new Font();
            module.moduleService_1_0 = cast moduleService;

            lm.setExport(SamHaXeModule.IMPORT_FUN_1_0, module.import_font_1_0);
            lm.setExport(SamHaXeModule.CHECK_FUN_1_0,  module.check_font_1_0);
            lm.setExport(SamHaXeModule.HELP_FUN_1_0,   module.help_font_1_0);

         default:
            throw "Unsupported interface version (" + version + ") requested!";
      }
            
      var native_init_fn = neko.Lib.load("font", "init", 0);
      native_init_fn();
      if(!native_init_fn())
         throw "Native font modul initialization failed!";
   }
   
   public static function main() {
      var lm = neko.vm.Module.local();
      
      lm.setExport(SamHaXeModule.INTERFACES,     interface_versions);
      lm.setExport(SamHaXeModule.DESCRIPTION,    description_font);
      lm.setExport(SamHaXeModule.INIT_MODULE,    initModule);
      lm.setExport(SamHaXeModule.INIT_INTERFACE, initInterface);
   }
}