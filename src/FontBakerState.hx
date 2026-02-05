package;

import State;
import App;
import Renderer;
import utils.FontBaker;
import utils.BakedFontData;
import display.BitmapFont;
import display.Text;
import entity.DisplayEntity;
import loaders.FontLoader;

/**
 * FontBakerState - Test state for baking TrueType fonts to bitmap atlases
 * 
 * This state demonstrates using stb_truetype to generate font atlases
 * from .ttf files. The baked fonts can then be used with the existing
 * BitmapFont/Text rendering system.
 */
class FontBakerState extends State {
    
    private var bitmapFont:BitmapFont;
    private var displayText:Text;
    private var fontEntity:DisplayEntity;
    private var currentFontSize:Float = 20.0;
    private var fontPath:String;
    private var outputName:String;
    private var cachedFontBytes:haxe.io.Bytes;
    private var cachedFontName:String;
    private var currentBakedData:BakedFontData;
    
    public function new(app:App) {
        super("FontBakerState", app);
    }
    
    override public function init():Void {
        super.init();
        
        // Set up orthographic camera for 2D text rendering
        camera.ortho = true;
        
        // Log camera and window info for debugging
        app.log.info(0, "=== Camera Setup ===");
        app.log.info(0, "Window size: " + app.WINDOW_WIDTH + "x" + app.WINDOW_HEIGHT);
        app.log.info(0, "Camera ortho: " + camera.ortho);
        app.log.info(0, "Camera zoom: " + camera.zoom);
        app.log.info(0, "Camera position: (" + camera.x + ", " + camera.y + ", " + camera.z + ")");
        
        trace("");
        trace("Press ESC to exit");
        trace("Press P to increase font size");
        trace("Press O to decrease font size");
    }
    
    /**
     * Import font - Load TTF, bake to RAM texture, display without exporting files
     * @param fontPath Path to the TTF font file
     * @param fontSize Font size in pixels
     */
    public function importFont(fontPath:String, fontSize:Float):Void {
        app.log.info(0, 'importFont called with path: "$fontPath", size: $fontSize');
        
        try {
            // Update current settings
            this.fontPath = fontPath;
            this.currentFontSize = fontSize;
            
            // Bake to RAM and display (without file export)
            app.log.info(0, 'Baking font to RAM (no file export)...');
            bakeFontToRAM(fontPath, fontSize);
            
        } catch (e:Dynamic) {
            app.log.error(0, 'Error in importFont: $e');
            throw e;
        }
    }
    
    /**
     * Export the currently imported/baked font to disk
     * Must call importFont() first to have font data to export
     * @param outputPath Full path where to save (e.g., "C:\\fonts\\arial_20" or with .json extension)
     */
    public function exportFont(outputPath:String):Void {
        app.log.info(0, 'exportFont called with path: "$outputPath"');
        
        try {
            // Validate that we have baked data to export
            if (currentBakedData == null) {
                throw "No font data to export. Call importFont() first!";
            }
            
            // Remove any extension if present (.json or .tga)
            var basePath = outputPath;
            var lowerPath = outputPath.toLowerCase();
            if (StringTools.endsWith(lowerPath, ".json")) {
                basePath = outputPath.substring(0, outputPath.length - 5);
            } else if (StringTools.endsWith(lowerPath, ".tga")) {
                basePath = outputPath.substring(0, outputPath.length - 4);
            }
            
            // Extract just the filename for logging
            var lastSlash = Std.int(Math.max(basePath.lastIndexOf("/"), basePath.lastIndexOf("\\")));
            var fileName = basePath.substring(lastSlash + 1);
            var dirPath = basePath.substring(0, lastSlash + 1);
            
            // Store output name
            this.outputName = fileName;
            
            app.log.info(0, 'Exporting current font data as: "$fileName"');
            app.log.info(0, 'To directory: "$dirPath"');
            
            // Export to disk using the base path (without extension)
            currentBakedData.exportToFiles(basePath);
            app.log.info(0, "Font exported successfully!");
            
        } catch (e:Dynamic) {
            app.log.error(0, 'Error in exportFont: $e');
            throw e;
        }
    }
    
    /**
     * Load and display a previously exported font
     * @param outputName Output name (without extension) of the baked font files
     */
    public function loadFont(outputName:String):Void {
        app.log.info(0, 'loadFont called with outputName: "$outputName"');
        
        try {
            this.outputName = outputName;
            
            // Setup and display (will reuse existing entity)
            app.log.info(0, 'Starting font setup...');
            setupBakedFont(app.renderer, outputName);
        } catch (e:Dynamic) {
            app.log.error(0, 'Error in loadFont: $e');
        }
    }
    
    /**
     * Bake font to RAM texture and display (no file export)
     */
    private function bakeFontToRAM(fontPath:String, fontSize:Float):Void {
        var separator = "";
        for (i in 0...60) separator += "=";
        
        app.log.info(0, separator);
        app.log.info(0, 'Baking font to RAM at ${fontSize}px (no export)');
        app.log.info(0, '  Input: "$fontPath"');
        app.log.info(0, separator);
        
        try {
            // Extract font name from path
            var lastSlash = Std.int(Math.max(fontPath.lastIndexOf("/"), fontPath.lastIndexOf("\\")));
            var fileName = fontPath.substring(lastSlash + 1);
            if (fileName.indexOf(".") > 0) {
                fileName = fileName.substring(0, fileName.lastIndexOf("."));
            }
            
            // Load font bytes from disk only if not cached or different font
            if (cachedFontBytes == null || cachedFontName != fileName) {
                app.log.info(0, "Loading font bytes from disk: " + fontPath);
                cachedFontBytes = sys.io.File.getBytes(fontPath);
                cachedFontName = fileName;
            } else {
                app.log.info(0, "Using cached font bytes for: " + fileName);
            }
            
            // Bake font in memory (no file I/O)
            var bakedData = FontBaker.bakeFontFromBytes(
                cachedFontBytes,
                fileName,
                fontSize,
                512,
                512,
                32,
                96
            );
            
            // Store for later export
            currentBakedData = bakedData;
            
            app.log.info(0, "Font baked to RAM, setting up display...");
            setupBakedFontFromData(app.renderer, bakedData);
        } catch (e:Dynamic) {
            app.log.error(0, 'Font RAM baking failed: $e');
            throw e;
        }
    }
    
    /**
     * Setup and display font from in-memory data
     */
    private function setupBakedFontFromData(renderer:Renderer, bakedData:BakedFontData):Void {
        app.log.info(0, "");
        app.log.info(0, "Setting up font from in-memory data...");
        
        try {
            // Build font data structure from BakedFontData
            var atlasFileName = bakedData.fontName + ".tga";
            var fontDataJson = {
                font: {
                    info: {
                        _face: bakedData.fontName,
                        _size: Std.string(bakedData.fontSize),
                        _bold: "0",
                        _italic: "0",
                        _charset: "",
                        _unicode: "1",
                        _stretchH: "100",
                        _smooth: "0",
                        _aa: "1",
                        _padding: "1,1,1,1",
                        _spacing: "1,1",
                        _outline: "0"
                    },
                    common: {
                        _lineHeight: Std.string(bakedData.lineHeight),
                        _base: Std.string(bakedData.base),
                        _scaleW: Std.string(bakedData.atlasWidth),
                        _scaleH: Std.string(bakedData.atlasHeight),
                        _pages: "1",
                        _packed: "0",
                        _alphaChnl: "0",
                        _redChnl: "4",
                        _greenChnl: "4",
                        _blueChnl: "4"
                    },
                    metrics: bakedData.metrics,
                    pages: {
                        page: {
                            _id: "0",
                            _file: atlasFileName
                        }
                    },
                    chars: {
                        char: bakedData.chars
                    }
                }
            };
            
            var fontData = FontLoader.load(haxe.Json.stringify(fontDataJson));
            app.log.info(0, 'Font data created, characters: ${Lambda.count(fontData.chars)}');
            
            // Log font metrics for debugging
            if (fontData.chars.exists(65)) { // 'A' character
                var charA = fontData.chars.get(65);
                app.log.info(0, 'Sample char "A": width=${charA.width}, height=${charA.height}, advance=${charA.xadvance}');
            }
            app.log.info(0, 'Font metrics - base: ${fontData.base}, lineHeight: ${fontData.lineHeight}');
            
            // Use texture data directly from memory
            var fontTexture = renderer.uploadTexture(bakedData.textureData);
            app.log.info(0, 'Font texture uploaded from memory, ID: ${fontTexture.id}');
            
            // Create text shader
            app.log.info(0, "Loading text shaders...");
            var textVertShader = app.resources.getText("shaders/text.vert");
            var textFragShader = app.resources.getText("shaders/text.frag");
            var textProgramInfo = renderer.createProgramInfo("text", textVertShader, textFragShader);
            
            // Create bitmap font
            app.log.info(0, "Creating BitmapFont...");
            bitmapFont = new BitmapFont(textProgramInfo, fontTexture, fontData);
            bitmapFont.init(renderer);
            
            app.log.info(0, "BitmapFont created, visible=" + bitmapFont.visible);
            
            // Create text to display
            var centerX = app.window.size.x / 2 - 150;
            var centerY = app.window.size.y / 2;
            
            // Round positions to whole pixels for pixel-perfect rendering
            centerX = Math.round(centerX);
            centerY = Math.round(centerY);
            
            displayText = new Text(bitmapFont, 
                "Hello, World!\nBaked Font Test\n" + bakedData.fontName + " @ " + Std.int(currentFontSize) + "px\n\nABCDEFGHIJKLMNOPQRSTUVWXYZ\nabcdefghijklmnopqrstuvwxyz\n0123456789\n!@#$%^&*()_+-=[]{}|;':,\",./<>?",
                centerX, 
                centerY - 100
            );
            
            // Update buffers after adding text tiles
            bitmapFont.needsBufferUpdate = true;
            bitmapFont.updateBuffers(renderer);
            
            // Reuse or create font entity
            if (fontEntity == null) {
                fontEntity = new DisplayEntity(bitmapFont, "baked_font_display");
                addEntity(fontEntity);
                app.log.info(0, "Created new font entity");
            } else {
                fontEntity.displayObject = bitmapFont;
                app.log.info(0, "Updated existing font entity");
            }
            
            app.log.info(0, "Font displayed successfully from memory!");
            app.log.info(0, "BitmapFont has " + bitmapFont.getTileCount() + " tiles");
        } catch (e:Dynamic) {
            app.log.error(0, "Failed to setup font from data - " + e);
        }
    }
    
    /**
     * Setup and display the baked font from disk files
            // Display the font
            setupBakedFontFromData(app.renderer, bakedDatat character (space)
                96                          // Number of characters (ASCII printable)
            );
            
            app.log.info(0, "Font baking complete!");
        } catch (e:Dynamic) {
            app.log.error(0, 'Font baking failed: $e');
            throw e;
        }
    }
    
    /**
     * Setup and display the baked font
     */
    private function setupBakedFont(renderer:Renderer, outputName:String):Void {
        app.log.info(0, "");
        app.log.info(0, "Loading baked font for display...");
        
        try {
            // Build full paths - add .json/.tga extension if not present
            var jsonPath = outputName;
            var lowerJson = jsonPath.toLowerCase();
            if (lowerJson.indexOf(".json") != lowerJson.length - 5) {
                jsonPath += ".json";
            }
            var tgaPath = outputName;
            var lowerTga = tgaPath.toLowerCase();
            if (lowerTga.indexOf(".json") == lowerTga.length - 5) {
                tgaPath = tgaPath.substring(0, tgaPath.length - 5);
                lowerTga = tgaPath.toLowerCase();
            }
            if (lowerTga.indexOf(".tga") != lowerTga.length - 4) {
                tgaPath += ".tga";
            }
            
            app.log.info(0, '  JSON path: "$jsonPath"');
            app.log.info(0, '  Texture path: "$tgaPath"');
            
            // Load font JSON using app.loadBytes for runtime files
            var jsonBytes = app.loadBytes(jsonPath);
            var jsonText = jsonBytes.toString();
            app.log.info(0, 'Font JSON loaded successfully, length: ${jsonText.length}');
            var fontData = FontLoader.load(jsonText);
            app.log.info(0, 'Font data parsed, characters: ${Lambda.count(fontData.chars)}');
            
            // Log font metrics for debugging
            if (fontData.chars.exists(65)) { // 'A' character
                var charA = fontData.chars.get(65);
                app.log.info(0, 'Sample char "A": width=${charA.width}, height=${charA.height}, advance=${charA.xadvance}');
            }
            app.log.info(0, 'Font metrics - base: ${fontData.base}, lineHeight: ${fontData.lineHeight}');
            
            // Load font texture using app.loadBytes for runtime files
            var tgaBytes = app.loadBytes(tgaPath);
            var fontTextureData = loaders.TGALoader.loadFromBytes(tgaBytes);
            app.log.info(0, 'Font texture loaded: ${fontTextureData.width}x${fontTextureData.height}');
            
            var fontTexture = renderer.uploadTexture(fontTextureData);
            app.log.info(0, 'Font texture uploaded, ID: ${fontTexture.id}');
            
            // Create text shader
            app.log.info(0, "Loading text shaders...");
            var textVertShader = app.resources.getText("shaders/text.vert");
            app.log.info(0, 'text.vert loaded: ${textVertShader != null}, length=${textVertShader != null ? textVertShader.length : 0}');
            var textFragShader = app.resources.getText("shaders/text.frag");
            app.log.info(0, 'text.frag loaded: ${textFragShader != null}, length=${textFragShader != null ? textFragShader.length : 0}');
            var textProgramInfo = renderer.createProgramInfo("text", textVertShader, textFragShader);
            
            app.log.info(0, "Shader program created: " + (textProgramInfo != null));
            app.log.info(0, "Font texture ID: " + fontTexture.id);
            app.log.info(0, "Font texture size: " + fontTextureData.width + "x" + fontTextureData.height);
            
            // Create bitmap font
            app.log.info(0, "Creating BitmapFont...");
            bitmapFont = new BitmapFont(textProgramInfo, fontTexture, fontData);
            bitmapFont.init(renderer);
            
            app.log.info(0, "BitmapFont created, visible=" + bitmapFont.visible);
            
            // Create text to display
            var centerX = app.window.size.x / 2 - 150;
            var centerY = app.window.size.y / 2;
            
            // Round positions to whole pixels for pixel-perfect rendering
            centerX = Math.round(centerX);
            centerY = Math.round(centerY);
            
            app.log.info(0, "Window size: " + app.window.size.x + "x" + app.window.size.y);
            app.log.info(0, "Text position: (" + centerX + ", " + (centerY - 100) + ")");
            app.log.info(0, "Camera zoom: " + camera.zoom);
            
            displayText = new Text(bitmapFont, 
                "Hello, World!\nBaked Font Test\nNokia FC22 @ " + Std.int(currentFontSize) + "px\n\nABCDEFGHIJKLMNOPQRSTUVWXYZ\nabcdefghijklmnopqrstuvwxyz\n0123456789\n!@#$%^&*()_+-=[]{}|;':,\",./<>?",
                centerX, 
                centerY - 100
            );
            
            app.log.info(0, "Text created, visible=" + displayText.visible);
            app.log.info(0, "Text size: " + displayText.width + "x" + displayText.height);
            app.log.info(0, "Tiles before buffer update: " + bitmapFont.getTileCount());
            app.log.info(0, "Atlas regions defined: " + Lambda.count(bitmapFont.atlasRegions));
            
            // Update buffers after adding text tiles
            bitmapFont.needsBufferUpdate = true;
            bitmapFont.updateBuffers(renderer);
            
            app.log.info(0, "Buffers updated");
            
            // Reuse or create font entity
            if (fontEntity == null) {
                fontEntity = new DisplayEntity(bitmapFont, "baked_font_display");
                addEntity(fontEntity);
                app.log.info(0, "Created new font entity");
            } else {
                fontEntity.displayObject = bitmapFont;
                app.log.info(0, "Updated existing font entity");
            }
            
            app.log.info(0, "Entity active=" + fontEntity.active + ", visible=" + fontEntity.visible);
            app.log.info(0, "DisplayObject visible=" + fontEntity.displayObject.visible);
            app.log.info(0, "Total entities in state: " + entities.length);
            
            app.log.info(0, "Baked font displayed successfully!");
            app.log.info(0, "BitmapFont has " + bitmapFont.getTileCount() + " tiles");
        } catch (e:Dynamic) {
            app.log.error(0, "Failed to load or display font - " + e);
        }
    }
    
    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        
        // Check for ESC to exit
        if (app.input.keyboard.pressed(Keycode.ESCAPE)) { // ESC key
            trace("FontBakerState: Exiting...");
            #if sys
            Sys.exit(0);
            #end
        }
        
        // Check for P key to increase font size (scancode 19 = 'P')
        if (app.input.keyboard.pressed(Keycode.P)) {
            currentFontSize += 1.0;
            if (currentFontSize > 64.0) currentFontSize = 64.0; // Max size
            trace("FontBakerState: Increasing font size to " + currentFontSize + "px");
            if (cachedFontBytes != null) {
                rebakeFont(currentFontSize);
            }
        }
        
        // Check for O key to decrease font size (scancode 18 = 'O')
        if (app.input.keyboard.pressed(Keycode.O)) {
            currentFontSize -= 1.0;
            if (currentFontSize < 4.0) currentFontSize = 4.0; // Min size
            trace("FontBakerState: Decreasing font size to " + currentFontSize + "px");
            if (cachedFontBytes != null) {
                rebakeFont(currentFontSize);
            }
        }
    }
    
    /**
     * Rebake the currently loaded font with new settings
     * Must call importFont() first to have a font path loaded
     * @param fontSize Font size in pixels
     * @param atlasWidth Atlas texture width (default 512)
     * @param atlasHeight Atlas texture height (default 512)
     * @param firstChar First character to bake (default 32 = space)
     * @param numChars Number of characters to bake (default 96 = ASCII printable)
     */
    public function rebakeFont(fontSize:Float, atlasWidth:Int = 512, atlasHeight:Int = 512, 
                               firstChar:Int = 32, numChars:Int = 96):Void {
        app.log.info(0, 'rebakeFont called with size: $fontSize, atlas: ${atlasWidth}x${atlasHeight}, range: $firstChar-${firstChar + numChars - 1}');
        
        try {
            // Validate that we have a font path and bytes
            if (cachedFontBytes == null || cachedFontName == null) {
                throw "No font loaded. Call importFont() first!";
            }
            
            // Update current size
            this.currentFontSize = fontSize;
            
            var separator = "";
            for (i in 0...60) separator += "=";
            
            app.log.info(0, separator);
            app.log.info(0, 'Rebaking font: $cachedFontName at ${fontSize}px');
            app.log.info(0, '  Atlas: ${atlasWidth}x${atlasHeight}');
            app.log.info(0, '  Character range: $firstChar-${firstChar + numChars - 1} ($numChars chars)');
            app.log.info(0, separator);
            
            // Bake font with new settings
            var bakedData = FontBaker.bakeFontFromBytes(
                cachedFontBytes,
                cachedFontName,
                fontSize,
                atlasWidth,
                atlasHeight,
                firstChar,
                numChars
            );
            
            // Store for later export
            currentBakedData = bakedData;
            
            app.log.info(0, "Font rebaked successfully, updating display...");
            setupBakedFontFromData(app.renderer, bakedData);
            
        } catch (e:Dynamic) {
            app.log.error(0, 'Font rebaking failed: $e');
            throw e;
        }
    }
    
    private var renderFrameCount:Int = 0;
    
    override public function render(renderer:Renderer):Void {
        // Enable alpha blending for text transparency
        renderer.setBlendMode(true);
        
        // Only log first 3 frames to reduce spam
        if (renderFrameCount < 3) {
            if (bitmapFont != null) {
                trace("FontBakerState: DEBUG RENDER - Font tiles: " + bitmapFont.getTileCount() + ", visible: " + bitmapFont.visible);
            }
            
            var renderCount = 0;
            for (entity in entities) {
                if (entity != null && entity.active && entity.visible) {
                    renderCount++;
                }
            }
            trace("FontBakerState: DEBUG RENDER - Rendering " + renderCount + "/" + entities.length + " entities");
            renderFrameCount++;
        }
        
        super.render(renderer);
    }
}
