#!/usr/bin/python

# From:
# http://pysnippet.blogspot.com/2009/12/when-ctypes-comes-to-rescue.html

import ctypes
import os

# gphoto structures
""" From 'gphoto2-camera.h'
typedef struct {
        char name [128];
        char folder [1024];
} CameraFilePath;
"""
class CameraFilePath(ctypes.Structure):
    _fields_ = [('name', (ctypes.c_char * 128)),
                ('folder', (ctypes.c_char * 1024))]

# gphoto constants
# Defined in 'gphoto2-port-result.h'
GP_OK = 0
# CameraCaptureType enum in 'gphoto2-camera.h'
GP_CAPTURE_IMAGE = 0
# CameraFileType enum in 'gphoto2-file.h'
GP_FILE_TYPE_NORMAL = 1





class CameraController():
    def __init__(self):
        # Load library
        self.gp = ctypes.CDLL('libgphoto2.so.2')

        # Init camera
        self.context = self.gp.gp_context_new()
        self.camera = ctypes.c_void_p()
        self.gp.gp_camera_new(ctypes.pointer(self.camera))
        self.gp.gp_camera_init(self.camera, self.context)

    def __del__(self):
        # Release the camera
        self.gp.gp_camera_exit(self.camera, self.context)
        self.gp.gp_camera_unref(self.camera)

    def capture(self, name):
        # Capture image
        cam_path = CameraFilePath()
        self.gp.gp_camera_capture(self.camera,
                             GP_CAPTURE_IMAGE,
                             ctypes.pointer(cam_path),
                             self.context)

        # Download and delete
        cam_file = ctypes.c_void_p()
        fd = os.open(name, os.O_CREAT | os.O_WRONLY)
        self.gp.gp_file_new_from_fd(ctypes.pointer(cam_file), fd)
        self.gp.gp_camera_file_get(self.camera,
                              cam_path.folder,
                              cam_path.name,
                              GP_FILE_TYPE_NORMAL,
                              cam_file,
                              self.context)
        self.gp.gp_camera_file_delete(self.camera,
                                 cam_path.folder,
                                 cam_path.name,
                                 self.context)
        self.gp.gp_file_unref(cam_file)

"""
Usage:
myCam = CameraController()

myCam.capture("test.jpg")
myCam.capture("test2.jpg")
"""
