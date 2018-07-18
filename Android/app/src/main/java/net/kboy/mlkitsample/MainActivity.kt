package net.kboy.mlkitsample

import android.hardware.Camera
import android.hardware.camera2.CameraDevice
import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.support.v4.app.ActivityCompat
import android.util.Log
import android.view.SurfaceHolder
import android.view.SurfaceView
import java.util.jar.Manifest

class MainActivity : AppCompatActivity(), ActivityCompat.OnRequestPermissionsResultCallback {

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode.toString() == android.Manifest.permission.CAMERA) {

        }
    }

    private var surfaceView: SurfaceView? = null
    private var camera: Camera? = null
    private val callBack = object: SurfaceHolder.Callback {
        override fun surfaceCreated(holder: SurfaceHolder?) {
            camera = Camera.open()

            try {
                camera?.setPreviewDisplay(holder)
            } catch (e: Exception){
                e.printStackTrace()
            }
        }

        override fun surfaceChanged(holder: SurfaceHolder?, format: Int, width: Int, height: Int) {
            camera?.startPreview()
        }

        override fun surfaceDestroyed(holder: SurfaceHolder?) {
            camera?.release()
            camera = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        ActivityCompat.requestPermissions(this,
                arrayOf(android.Manifest.permission.CAMERA), 0)

        surfaceView = findViewById(R.id.mySurfaceView)

        val holder = surfaceView?.holder
        holder?.addCallback(callBack)
    }
}
