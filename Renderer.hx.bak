package;

import cpp.RawConstPointer;
import cpp.ConstCharStar;
import cpp.RawPointer;
import GL;
import ProgramInfo;
import DisplayObject;
import data.TextureData;
import Texture;
import math.Matrix;
import cpp.Float32;
import cpp.UInt32;
import Framebuffer;

typedef RenderState = {
    depthTest:Bool,
    depthWrite:Bool,
    blendMode:Bool
}

class Renderer {
    
    // Publics
    public var app(get, null):App;
    //public var windowWidth:Int;
    //public var windowHeight:Int;
    
    // Current render state tracking
    private var __currentDepthTest:Bool = true;
    private var __currentDepthWrite:Bool = true;
    private var __currentBlendMode:Bool = false;
    private var __app:App;
    private var frameCount:Int = 0;
    private var programInfos:Map<String, ProgramInfo> = new Map<String, ProgramInfo>();

    // Framebuffer for post-processing
    public var framebuffer:Framebuffer = null;
    public var postProcessShader:ProgramInfo = null;
    private var __fullscreenQuadVAO:Int = 0;
    private var __fullscreenQuadVBO:Int = 0;
    public var usePostProcessing:Bool = false; // Toggle post-processing on/off
    private var currentProgram:Int = -1;
    
    public function new(app:App, windowWidth:Int, windowHeight:Int) {
        this.__app = app;
        //this.windowWidth = windowWidth;
        //this.windowHeight = windowHeight;
    }
    
    public function render():Void {
        currentProgram = -1;
        frameCount++;
    }
    
    // ** New method to render display objects with provided view-projection matrix
    public function renderDisplayObject(displayObject:DisplayObject, viewProjectionMatrix:math.Matrix):Void {
        if (!displayObject.visible) return;
        
        // ALWAYS update buffers for orphaning strategy (rebuilds every frame)
        displayObject.updateBuffers(this);
        //uploadData(displayObject);
        
        displayObject.render(viewProjectionMatrix);

        if (displayObject.vertices.length == 0) return;

        // Use the program
        if (displayObject.programInfo.program != currentProgram) {
            GL.useProgram(displayObject.programInfo.program);
            currentProgram = displayObject.programInfo.program;
        }

        // Bind VAO (shared from ProgramInfo)
        GL.bindVertexArray(displayObject.programInfo.vao);
        
        // Bind VBO to ARRAY_BUFFER (required for compatibility with data upload)
        GL.bindBuffer(GL.ARRAY_BUFFER, displayObject.vbo);
        
        // Also bind using modern ARB_vertex_attrib_binding
        GL.bindVertexBuffer(0, displayObject.vbo, 0, displayObject.programInfo.vertexStride);
        
        // Bind element buffer if available
        if (displayObject.ebo != 0 && displayObject.indices.length > 0) {
            GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, displayObject.ebo);
        }

        // Render uniforms and textures
        __renderUniforms(displayObject.programInfo, displayObject.uniforms);
        __renderTextures(displayObject.programInfo, displayObject);

        // Draw the object
        if (displayObject.__indicesToRender == 0) {
            GL.drawArrays(displayObject.mode, 0, displayObject.__verticesToRender);
        } else {
            GL.drawElements(displayObject.mode, displayObject.__indicesToRender, GL.UNSIGNED_INT, 0);
        }

        displayObject.postRender();

        GL.bindVertexArray(0);
    }

    private function __renderUniforms(programInfo:ProgramInfo, uniforms:Map<String, Dynamic>):Void {
        // Use pre-computed uniform setters for optimal performance - no more switch/case in render loop!
        for (name => value in uniforms) {
            // O(1) lookup using pre-computed uniform map
            var uniformInfo = programInfo.getUniform(name);
            
            if (uniformInfo == null) {
                // TODO: Convert to proper logging - __app.trace(21, "Warning: Uniform '" + name + "' not found in shader");
                trace("Warning: Uniform '" + name + "' not found in shader");
                continue; // Uniform doesn't exist in shader
            }
            
            // Use pre-computed setter function - direct function call, no branching!
            // This eliminates the switch/case overhead completely
            uniformInfo.setter(value);
        }
    }

    private function __renderTextures(programInfo:ProgramInfo, drawable:DisplayObject):Void {
        for (i in 0...programInfo.textures.length) {
            var x = GL.TEXTURE0 + i;
            GL.activeTexture(x);

            if (i < drawable.textures.length) {
                var texture = drawable.textures[i];
                var textureId = texture != null ? texture.id : 0;
                GL.bindTexture(GL.TEXTURE_2D, textureId);
            }

            GL.blendFunc(drawable.blendFactors.source, drawable.blendFactors.destination);
            
            drawable.programInfo.textures[i].setter(i);
        }
    }
    
    /**
     * Create and register a ProgramInfo if it doesn't exist, or return existing one
     * This is the proper way for States to request ProgramInfos from Renderer
     */
    public function createProgramInfo(name:String, vertexShader:String, fragmentShader:String):ProgramInfo {
        // Check if this ProgramInfo already exists
        if (programInfos.exists(name)) {
            return programInfos.get(name);
        }
        
        // Create new ProgramInfo and register it
        var programInfo = new ProgramInfo(name, this, vertexShader, fragmentShader);
        programInfos.set(name, programInfo);

        // TODO: Convert to proper logging system once cross-class access is resolved
        // trace("Created and registered ProgramInfo: " + name);
        return programInfo;
    }
    
    /**
     * Get a ProgramInfo by name
     * Used by States to retrieve ProgramInfos for creating DisplayObjects
     */
    public function getProgramInfo(name:String):ProgramInfo {
        if (!programInfos.exists(name)) {
            trace("Error: ProgramInfo '" + name + "' not found!");
            return null;
        }
        return programInfos.get(name);
    }
    
    /**
     * Check if a ProgramInfo is already registered
     */
    public function hasProgramInfo(name:String):Bool {
        return programInfos.exists(name);
    }
    
    /**
     * Create and register a ProgramInfo from preloaded shader files
     * This method uses the App's resource system to load shader files
     */
    public function createProgramInfoFromFiles(name:String, vertexShaderPath:String, fragmentShaderPath:String):ProgramInfo {
        // Check if this ProgramInfo already exists
        if (programInfos.exists(name)) {
            trace("ProgramInfo '" + name + "' already exists, reusing...");
            return programInfos.get(name);
        }
        
        // Get shader source from preloaded resources
        var vertexShader = app.resources.getText(vertexShaderPath);
        var fragmentShader = app.resources.getText(fragmentShaderPath);
        
        if (vertexShader == null) {
            trace("Error: Vertex shader '" + vertexShaderPath + "' not found in preloaded resources!");
            return null;
        }
        
        if (fragmentShader == null) {
            trace("Error: Fragment shader '" + fragmentShaderPath + "' not found in preloaded resources!");
            return null;
        }
        
        // Create new ProgramInfo and register it
        var programInfo = new ProgramInfo(name, this, vertexShader, fragmentShader);
        programInfos.set(name, programInfo);
        
        trace("Created ProgramInfo '" + name + "' from preloaded shaders: " + vertexShaderPath + ", " + fragmentShaderPath);
        return programInfo;
    }
    
    /**
     * Get all registered ProgramInfo names
     */
    public function getProgramInfoNames():Array<String> {
        var names:Array<String> = [];
        for (name in programInfos.keys()) {
            names.push(name);
        }
        return names;
    }

    // ===== RENDERING PIPELINE METHODS =====

    public function createBuffers():{vbo:GlUInt, ebo:GlUInt} {

        var vbo:GlUInt = 0;
        var ebo:GlUInt = 0;
        GL.genBuffers(1, RawPointer.addressOf(vbo));
        GL.genBuffers(1, RawPointer.addressOf(ebo));

        return {vbo: vbo, ebo: ebo};
    }

    // Upload vertex data to GPU
    public function uploadData(displayObject:DisplayObject):Void {
        GL.bindVertexArray(displayObject.programInfo.vao);
        GL.bindBuffer(GL.ARRAY_BUFFER, displayObject.vbo);
        GL.bufferFloatArray(GL.ARRAY_BUFFER, displayObject.vertices, GL.DYNAMIC_DRAW, displayObject.vertices.length);
        if (displayObject.ebo != 0 && displayObject.indices.length > 0) {
            GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, displayObject.ebo);
            GL.bufferUIntArray(GL.ELEMENT_ARRAY_BUFFER, displayObject.indices, GL.DYNAMIC_DRAW, displayObject.indices.length);
        }

        GL.bindBuffer(GL.ARRAY_BUFFER, 0);
        GL.bindVertexArray(0);
    }

        public function orphanAndUploadData(displayObject:DisplayObject, maxBufferSize:Int):Void {
        GL.bindVertexArray(displayObject.programInfo.vao);
        GL.bindBuffer(GL.ARRAY_BUFFER, displayObject.vbo);
        untyped __cpp__("glBufferData({0}, {1}, NULL, {2})", GL.ARRAY_BUFFER, maxBufferSize, GL.STREAM_DRAW);
        GL.bufferFloatArray(GL.ARRAY_BUFFER, displayObject.vertices, GL.STREAM_DRAW, displayObject.vertices.length);
        if (displayObject.ebo != 0 && displayObject.indices.length > 0) {
            GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, displayObject.ebo);
            GL.bufferUIntArray(GL.ELEMENT_ARRAY_BUFFER, displayObject.indices, GL.STREAM_DRAW, displayObject.indices.length);
        }

        GL.bindBuffer(GL.ARRAY_BUFFER, 0);
        GL.bindVertexArray(0);
    }
    
    /**
     * Allocate buffers for TileBatch (called once)
     * @param displayObject TileBatch object
     * @param maxTiles Maximum tile capacity
     */
    public function allocateTileBatchBuffers(displayObject:DisplayObject, maxTiles:Int):Void {
        GL.bindVertexArray(displayObject.programInfo.vao);
        
        // Allocate vertex buffer (4 vertices × 5 floats per tile)
        GL.bindBuffer(GL.ARRAY_BUFFER, displayObject.vbo);
        var vertexBufferSize = maxTiles * 4 * 5 * 4; // tiles × vertices × floats × 4 bytes
        // Use GL_STREAM_DRAW for buffers that will be orphaned frequently
        untyped __cpp__("glBufferData({0}, {1}, NULL, {2})", GL.ARRAY_BUFFER, vertexBufferSize, GL.STREAM_DRAW);
        
        // Upload index buffer once (indices never change)
        if (displayObject.ebo != 0 && displayObject.indices.length > 0) {
            GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, displayObject.ebo);
            GL.bufferUIntArray(GL.ELEMENT_ARRAY_BUFFER, displayObject.indices, GL.STATIC_DRAW, displayObject.indices.length);
        }
        
        GL.bindBuffer(GL.ARRAY_BUFFER, 0);
        GL.bindVertexArray(0);
    }
    
    /**
     * Orphan and upload TileBatch vertex data (called every frame)
     * @param displayObject TileBatch object
     */
    public function orphanAndUploadTileBatch(displayObject:DisplayObject):Void {
        if (displayObject.vertices.length == 0) return;
        
        GL.bindVertexArray(displayObject.programInfo.vao);
        GL.bindBuffer(GL.ARRAY_BUFFER, displayObject.vbo);
        
        // Orphan buffer - tell driver we don't need old data
        var vertexBufferSize = 1000 * 4 * 5 * 4; // MAX_TILES × 4 vertices × 5 floats × 4 bytes
        untyped __cpp__("glBufferData({0}, {1}, NULL, {2})", GL.ARRAY_BUFFER, vertexBufferSize, GL.DYNAMIC_DRAW);
        
        // Upload actual vertex data
        var floatArray:Array<Float> = cast displayObject.vertices.data;
        GL.bufferSubFloatArray(GL.ARRAY_BUFFER, 0, floatArray, floatArray.length);
        
        GL.bindBuffer(GL.ARRAY_BUFFER, 0);
        GL.bindVertexArray(0);
    }

    // TODO: programInfo.setupVertexAttributes(this); This must be called in the beginning of the draw. Now it is called for every DisplayObject.
    /**
     * Set up vertex attributes and finalize buffer setup
     */
    // public function setupVertexAttributes(programInfo:ProgramInfo):Void {
    //     //GL.bindVertexArray(programInfo.vao);
    //     programInfo.setupVertexAttributes(this);
    //     GL.bindVertexArray(0);
    //     // Unbind buffers
    //     //GL.bindBuffer(GL.ARRAY_BUFFER, 0); // TODO: We got bind and unbind separated. Union in 1 function.
    //     //GL.bindVertexArray(0);
    // }

    public function deleteBuffers(vbo:GlUInt, ebo:GlUInt):Void {
        GL.deleteBuffers(1, RawPointer.addressOf(vbo));
        GL.deleteBuffers(1, RawPointer.addressOf(ebo));
    }

    /**
     * Clear the screen and prepare for rendering
     */
    public function clearScreen():Void {
        GL.glClearColor(0.1, 0.1, 0.15, 1.0); // Very dark background for 3D focus
        GL.glClear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
    }

    /**
     * Initialize rendering state
     */
    public function initializeRenderState():Void {
        // Enable depth testing for 3D
        // GL.glEnable(GL.DEPTH_TEST);
        // GL.glDepthFunc(GL.LESS);
        
        // Disable face culling to see all faces from all angles
        GL.glDisable(GL.CULL_FACE);
    }


    // TODO: Move to GL
    public function vertexAttribPointer(index:Int, size:Int, type:Int, normalized:Bool, stride:Int, offset:Int):Void {
        untyped __cpp__("glVertexAttribPointer({0}, {1}, {2}, {3} ? GL_TRUE : GL_FALSE, {4}, (void*)(intptr_t){5})", index, size, type, normalized, stride, offset);
    }

    /**
     * Upload TextureData to OpenGL and return Texture object
     */
    public function uploadTexture(textureData:TextureData):Texture {
        if (textureData == null) {
            trace("Error: Cannot upload null texture data");
            return null;
        }
        
        // var textureArray:Array<UInt> = [0];
        // GL.genTextures(1, untyped __cpp__("(unsigned int*)&{0}[0]", textureArray));
        // var textureId:UInt = textureArray[0];

        var textureId:GlUInt = 0;
        GL.genTextures(1, RawPointer.addressOf(textureId));
        
        GL.bindTexture(GL.TEXTURE_2D, textureId);
        
        // Set texture parameters
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
        
        // Upload actual texture data with correct format based on BPP
        var format:Int;
        var internalFormat:Int;
        
        switch (textureData.bytesPerPixel) {
            case 1: // Grayscale/monochrome
                format = GL.RED;
                internalFormat = GL.RED;
            case 2: // Grayscale + Alpha
                format = GL.RG;
                internalFormat = GL.RG;
            case 3: // RGB
                format = GL.RGB;
                internalFormat = GL.RGB;
            case 4: // RGBA
                format = GL.RGBA;
                internalFormat = GL.RGBA;
            default:
                throw "Unsupported texture format: " + textureData.bytesPerPixel + " bytes per pixel";
        }
                    
        GL.texImage2D(GL.TEXTURE_2D, 0, internalFormat, textureData.width, textureData.height, 0, format, GL.UNSIGNED_BYTE, textureData.bytes.getData().bytes);
        GL.bindTexture(GL.TEXTURE_2D, 0);

        var texture:Texture = {
            id: textureId,
            width: textureData.width,
            height: textureData.height,
            bpp: textureData.bytesPerPixel,
            target: GL.TEXTURE_2D
        };
        
        return texture;
    }

    public function release():Void {
        // Reset render state
        setDepthTest(true);
        setDepthWrite(true);
        setBlendMode(false);
        
        // Cleanup framebuffer
        if (framebuffer != null) {
            framebuffer.dispose();
            framebuffer = null;
        }
        
        // Cleanup all registered ProgramInfos
        for (name in programInfos.keys()) {
            var programInfo = programInfos.get(name);
            if (programInfo != null) {
                programInfo.dispose(this);
                trace("Disposed ProgramInfo: " + name);
            }
        }
        programInfos.clear();
        
        trace("Renderer cleanup complete");
    }
    
    /**
     * Render state management methods
     */
    public function setDepthTest(enabled:Bool):Void {
        if (__currentDepthTest != enabled) {
            if (enabled) {
                GL.glEnable(GL.DEPTH_TEST);
            } else {
                GL.glDisable(GL.DEPTH_TEST);
            }
            __currentDepthTest = enabled;
        }
    }
    
    public function setDepthWrite(enabled:Bool):Void {
        if (__currentDepthWrite != enabled) {
            // For now, skip depth mask as it's not in GL.hx yet
            // GL.depthMask(enabled);
            __currentDepthWrite = enabled;
        }
    }
    
    public function setBlendMode(enabled:Bool):Void {
        if (__currentBlendMode != enabled) {
            if (enabled) {
                GL.glEnable(GL.BLEND);
                GL.blendFunc(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA);
            } else {
                GL.glDisable(GL.BLEND);
            }
            __currentBlendMode = enabled;
        }
    }
    
    public function pushRenderState():RenderState {
        return {
            depthTest: __currentDepthTest,
            depthWrite: __currentDepthWrite,
            blendMode: __currentBlendMode
        };
    }
    
    public function popRenderState(state:RenderState):Void {
        setDepthTest(state.depthTest);
        setDepthWrite(state.depthWrite);
        setBlendMode(state.blendMode);
    }

    
    // ===== SHADER WRAPPER FUNCTIONS =====
    // These functions are used by ProgramInfo for shader compilation
    // TODO: Consider having ProgramInfo call GL directly instead
    
    public function createShader(type:Int):Int {
        return GL.createShader(type);
    }

    // public function shaderSource(shader:Int, source:String):Void {
    //     untyped __cpp__("\n            const char* shaderSource = {1}.__s;\n            glShaderSource({0}, 1, &shaderSource, NULL);\n        ", shader, source);
    // }

    public function compileShader(shader:Int):Void {
        GL.compileShader(shader);
    }

    public function createProgram():Int {
        return GL.createProgram();
    }

    public function attachShader(program:Int, shader:Int):Void {
        GL.attachShader(program, shader);
    }

    public function linkProgram(program:Int):Void {
        GL.linkProgram(program);
    }

    public function useProgram(program:Int):Void {
        GL.useProgram(program);
    }

    public function deleteShader(shader:Int):Void {
        GL.deleteShader(shader);
    }

    public function getAttribLocation(program:Int, name:String):Int {
        return GL.getAttribLocation(program, name);
    }

    public function getUniformLocation(program:Int, name:String):Int {
        return GL.getUniformLocation(program, name);
    }

    public function enableVertexAttribArray(index:Int):Void {
        GL.enableVertexAttribArray(index);
    }

    // ===== DEPRECATED / UNUSED FUNCTIONS =====
    // These functions are kept for reference but are no longer used in the current architecture
    
    /*
    // No-op function that was kept for compatibility
    private function __renderAttributes(programInfo:ProgramInfo):Void {
        // Attributes are already set up in VAO, so this is essentially a no-op
        // for our current VAO-based implementation, but kept for compatibility
    }
    */

    // Getters and setters
    private function get_app():App {
        return __app;
    }

    // ** Helper: Convert AttributeFormat to GL constant for rendering
	private function getGLFormat(format:AttributeFormat):Int {
		return switch (format) {
			case AttributeFormat.Float | AttributeFormat.Vec2 | AttributeFormat.Vec3 | AttributeFormat.Vec4: 5126; // GL_FLOAT
			case AttributeFormat.Int: 5124;          // GL_INT
			case AttributeFormat.UnsignedInt: 5125;  // GL_UNSIGNED_INT
			case AttributeFormat.Byte: 5120;         // GL_BYTE
			case AttributeFormat.UnsignedByte: 5121; // GL_UNSIGNED_BYTE
			case AttributeFormat.Short: 5122;        // GL_SHORT
			case AttributeFormat.UnsignedShort: 5123;// GL_UNSIGNED_SHORT
		}
	}

    // ** Shader compilation and linking
	public function compileProgramInfo(programInfo:ProgramInfo):Bool {
		if (programInfo.isCompiled) return true;

        var vertContent = ConstCharStar.fromString(programInfo.vertexShaderSource);
        var fragContent = ConstCharStar.fromString(programInfo.fragmentShaderSource);

		// Vertex shader
		programInfo.vertexShader = createShader(GL.VERTEX_SHADER);
		GL.shaderSource(programInfo.vertexShader, 1, RawPointer.addressOf(vertContent), null);
		compileShader(programInfo.vertexShader);
		if (!checkShaderCompilation(programInfo.vertexShader, "Vertex")) {
			trace("Vertex shader compilation failed!");
			return false;
		}
		
		// Fragment shader
		programInfo.fragmentShader = createShader(GL.FRAGMENT_SHADER);
		GL.shaderSource(programInfo.fragmentShader, 1, RawPointer.addressOf(fragContent), null);
		compileShader(programInfo.fragmentShader);
		if (!checkShaderCompilation(programInfo.fragmentShader, "Fragment")) {
			trace("Fragment shader compilation failed!");
			return false;
		}

		// Create and link program
		programInfo.program = createProgram();
		
		attachShader(programInfo.program, programInfo.vertexShader);
		attachShader(programInfo.program, programInfo.fragmentShader);
		linkProgram(programInfo.program);
		
		// Check program linking
		if (!checkProgramLinking(programInfo.program)) {
			return false;
		}
		
		programInfo.isCompiled = true;
		return true;
	}

    private function checkShaderCompilation(shader:Int, type:String):Bool {
		var success:Int = GL.getShaderParameterValue(shader, GL.COMPILE_STATUS);
		
		if (success == 0) {
			// Compilation failed, get error log
			var errorLog:String = GL.getShaderInfoLogString(shader);
			
			if (errorLog.length > 0) {
				trace(type + " shader compilation failed:");
				trace(errorLog);
			} else {
				trace(type + " shader compilation failed with no error log");
			}
			return false;
		}
		
		trace(type + " shader compiled successfully");
		return true;
	}

	private function checkProgramLinking(program:Int):Bool {
		var success:Int = GL.getProgramParameterValue(program, GL.LINK_STATUS);
		
		if (success == 0) {
			// Linking failed, get error log
			var errorLog:String = GL.getProgramInfoLogString(program);
			
			if (errorLog.length > 0) {
				trace("Program linking failed:");
				trace(errorLog);
			} else {
				trace("Program linking failed with no error log");
			}
			return false;
		}
		
		trace("Program linked successfully");
		return true;
	}
	
	// =============================================================================
	// FRAMEBUFFER AND POST-PROCESSING
	// =============================================================================
	
	/**
	 * Initialize the post-processing framebuffer and fullscreen quad
	 */
	public function initializePostProcessing():Void {

        var size = app.window.getWindowSizeInPixels();

		// Create framebuffer
		framebuffer = new Framebuffer(size.width, size.height, false, true);
		
		// Create fullscreen quad for rendering
		createFullscreenQuad();
		
		// Create default post-process shader (passthrough)
		var vertShader = '
			#version 330 core
			layout (location = 0) in vec2 aPos;
			layout (location = 1) in vec2 aTexCoord;
			out vec2 TexCoord;
			
			void main() {
				gl_Position = vec4(aPos.x, aPos.y, 0.0, 1.0);
				TexCoord = aTexCoord;
			}
		';
		
		var fragShader = '
			#version 330 core
			in vec2 TexCoord;
			out vec4 FragColor;
			uniform sampler2D uScreenTexture;
			
			void main() {
				FragColor = texture(uScreenTexture, TexCoord);
			}
		';
		
		postProcessShader = createProgramInfo("PostProcess", vertShader, fragShader);
		
		trace("Renderer: Post-processing initialized");
	}
	
	/**
	 * Create a fullscreen quad (2 triangles)
	 */
	private function createFullscreenQuad():Void {
		// Fullscreen quad vertices: position (x,y) + texcoord (u,v)
		var quadVertices:Array<Float> = [
			// positions  // texCoords
			-1.0,  1.0,  0.0, 1.0, // top-left
			-1.0, -1.0,  0.0, 0.0, // bottom-left
			 1.0, -1.0,  1.0, 0.0, // bottom-right
			 1.0,  1.0,  1.0, 1.0  // top-right
		];
		
		var quadIndices:Array<UInt> = [
			0, 1, 2, // first triangle
			0, 2, 3  // second triangle
		];
		
		// Create VAO
		__fullscreenQuadVAO = GL.createVertexArray();
		GL.bindVertexArray(__fullscreenQuadVAO);
		
		// Create VBO
		__fullscreenQuadVBO = GL.createBuffer();
		GL.bindBuffer(GL.ARRAY_BUFFER, __fullscreenQuadVBO);
		
		// Convert vertex array to bytes
		var vertexBytes = haxe.io.Bytes.alloc(quadVertices.length * 4);
		for (i in 0...quadVertices.length) {
			vertexBytes.setFloat(i * 4, quadVertices[i]);
		}
		GL.bufferData(GL.ARRAY_BUFFER, vertexBytes.length, vertexBytes.getData(), GL.STATIC_DRAW);
		
		// Create EBO
		var ebo = GL.createBuffer();
		GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, ebo);
		
		// Convert index array to bytes
		var indexBytes = haxe.io.Bytes.alloc(quadIndices.length * 4);
		for (i in 0...quadIndices.length) {
			indexBytes.setInt32(i * 4, quadIndices[i]);
		}
        
		GL.bufferData(GL.ELEMENT_ARRAY_BUFFER, indexBytes.length, indexBytes.getData(), GL.STATIC_DRAW);
		
		// Position attribute
		
        GL.vertexAttribPointer(0, 2, GL.FLOAT, false, 4 * 4, untyped __cpp__("(void*)0")); // 4 floats per vertex, stride = 16 bytes

		GL.enableVertexAttribArray(0);
		
		// TexCoord attribute
		GL.vertexAttribPointer(1, 2, GL.FLOAT, false, 4 * 4, untyped __cpp__("(void*){0}", 2 * 4)); // offset = 8 bytes
		GL.enableVertexAttribArray(1);
		
		GL.bindVertexArray(0);
		
		trace("Renderer: Created fullscreen quad");
	}
	
	/**
	 * Bind the framebuffer for rendering
	 */
	public function bindFramebuffer():Void {
		if (framebuffer != null) {
			framebuffer.bind();
		}
	}
	
	/**
	 * Unbind the framebuffer (render to screen)
	 */
	public function unbindFramebuffer():Void {
		if (framebuffer != null) {
			framebuffer.unbind();
		}

        var size = app.window.getWindowSizeInPixels();
		GL.viewport(0, 0, size.width, size.height);
	}
	
    public function setViewport(width:Int, height:Int):Void {
        GL.viewport(0, 0, width, height);
    }

	/**
	 * Render the framebuffer texture to screen with post-process shader
	 */
	public function renderToScreen():Void {
		if (framebuffer == null || postProcessShader == null) {
			trace("Warning: Post-processing not initialized");
			return;
		}
		
		// Use post-process shader
		GL.useProgram(postProcessShader.program);
		
		// Bind framebuffer's color texture
		framebuffer.bindColorTexture(0);
		
		// Set uniform
		var uniformInfo = postProcessShader.getUniform("uScreenTexture");
		if (uniformInfo != null) {
			uniformInfo.setter(0);
		}
		
		// Render fullscreen quad
		GL.bindVertexArray(__fullscreenQuadVAO);
		GL.drawElements(GL.TRIANGLES, 6, GL.UNSIGNED_INT, 0);
		GL.bindVertexArray(0);
	}
}