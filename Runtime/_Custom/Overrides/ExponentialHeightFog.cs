using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;

namespace UnityEngine.Rendering.Universal.Custom
{
    [Serializable, VolumeComponentMenuForRenderPipeline("Post-processing/Custom/ExponentialHeightFog", typeof(UniversalRenderPipeline))]
    public class ExponentialHeightFog : VolumeComponent, IPostProcessComponent
    {
        private static Texture2D DefaultHeightNoiseTexture;
        private static Texture2D DefaultHeightColorRampTexture;

        public ClampedFloatParameter fogDensity = new ClampedFloatParameter(1.0f, 0.0f, 3.0f);
        public ClampedFloatParameter fogOpacity = new ClampedFloatParameter(0.5f, 0.0f, 1f);
        public FloatParameter fogHeight = new FloatParameter(0.0f);
        public ClampedFloatParameter heightFalloff = new ClampedFloatParameter(1f,0.0f,2f);
        public FloatParameter fogStartDistance = new FloatParameter(1f);
        public ColorParameter fogColor = new ColorParameter(Color.white);
        public FloatParameter inscatteringExponent = new FloatParameter(1f);
        public FloatParameter inscatteringStartDistance = new FloatParameter(1f);

        [Space]
        [Header("Height Noise")]
        public TextureParameter heightNoiseTexture = new TextureParameter(null);
        public Vector3Parameter heightNoiseScale = new Vector3Parameter(new Vector3(1f, 1f,1f));
        public Vector2Parameter heightNoiseFlowSpeed = new Vector2Parameter(new Vector2(1f, 1f));
        public FloatParameter heightNoisePower = new FloatParameter(1f);

        [Space]
        [Header("Height Color Ramp")]
        public TextureParameter heightColorRampTexture = new TextureParameter(null);
        public FloatParameter bottomHeight = new FloatParameter(0f);
        public FloatParameter topHeight = new FloatParameter(2f);

        public Texture HeightNoiseTexture 
        {
            get 
            {
                if (heightNoiseTexture.value == null)
                {
                    if (DefaultHeightNoiseTexture == null)
                    {
                        DefaultHeightNoiseTexture = new Texture2D(1,1);
                        DefaultHeightNoiseTexture.SetPixel(0, 0, new Color(0f, 0f, 0f));
                        DefaultHeightNoiseTexture.Apply();
                    }
                    return DefaultHeightNoiseTexture;
                }   
                else
                    return heightNoiseTexture.value;
            }
        }

        public Texture HeightColorRampTexture
        {
            get
            {
                if (heightColorRampTexture.value == null)
                {
                    if (DefaultHeightColorRampTexture == null)
                    {
                        DefaultHeightColorRampTexture = new Texture2D(1, 1);
                        DefaultHeightColorRampTexture.SetPixel(0, 0, new Color(1f, 1f, 1f));
                        DefaultHeightColorRampTexture.Apply();
                    }
                    return DefaultHeightColorRampTexture;
                }
                else
                    return heightColorRampTexture.value;
            }
        }


        public bool IsActive()
        {
            return active;
        }

        public bool IsTileCompatible()
        {
            return true;
        }
    }
}
