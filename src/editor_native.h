#ifndef EDITOR_NATIVE_H
#define EDITOR_NATIVE_H

#include <hx/Thread.h>
#include <windows.h>
#include <io.h>
#include <fcntl.h>
#include <stdio.h>

// Callback typedefs for C# to receive messages and events (MUST be outside extern "C")
typedef void (__cdecl *CustomCallback)(const char* message);
typedef void (__cdecl *MouseDownButtonCallback)(double x, double y, int button);

// C exports
extern "C" {
    // Global state (declared in Editor.hx @:cppFileCode)
    extern bool hxcpp_initialized;
    extern CustomCallback g_callback;
    __declspec(dllexport) const char* HxcppInit();

    __declspec(dllexport) void setCallback(CustomCallback callback);
    
    // Engine lifecycle functions
    __declspec(dllexport) int init();
    __declspec(dllexport) int initWithCallback(CustomCallback callback);
    __declspec(dllexport) void updateFrame(float deltaTime);
    __declspec(dllexport) void render();
    __declspec(dllexport) void swapBuffers();
    __declspec(dllexport) void shutdownEngine();
    __declspec(dllexport) void release();
    __declspec(dllexport) void loadState(int stateIndex);
    __declspec(dllexport) int isRunning();
    __declspec(dllexport) int getWindowWidth();
    __declspec(dllexport) int getWindowHeight();
    __declspec(dllexport) void setWindowSize(int width, int height);
    __declspec(dllexport) void* getWindowHandle();
    __declspec(dllexport) void setWindowPosition(int x, int y);
    __declspec(dllexport) void setWindowSizeAndBorderless(int width, int height);

    // Mouse input handling
    __declspec(dllexport) void onMouseMotion(int x, int y);
    __declspec(dllexport) void onMouseButtonDown(int x, int y, int button);
    __declspec(dllexport) void onMouseButtonUp(int x, int y, int button);
    __declspec(dllexport) void onKeyboardDown(int keyCode);
    __declspec(dllexport) void onKeyboardUp(int keyCode);
}

#endif // EDITOR_NATIVE_H
