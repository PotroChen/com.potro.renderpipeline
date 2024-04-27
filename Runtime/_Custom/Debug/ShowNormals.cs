using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ShowNormals : MonoBehaviour
{
    private enum State
    {
        None,
        ShowMeshNormals,
        ShowNormalsInVertices
    }

    private Mesh m_Mesh;
    private State m_State;

    public float m_LineLength = 0.01f;
    public Color m_LineColor = Color.black;

    [ContextMenu("显示Mesh.normals")]
    public void ShowMeshNormals()
    {
        Stop();

        m_Mesh = GetMesh();
        m_State = State.ShowMeshNormals;
    }

    [ContextMenu("假设Mesh.color储存normalOS,并显示")]
    public void ShowNormalsInColor()
    {
        Stop();

        m_Mesh = GetMesh();
        m_State = State.ShowNormalsInVertices;
    }

    private void OnDrawGizmos()
    {
        if (m_State == State.ShowMeshNormals)
        {
            var normals = m_Mesh.normals;
            var vertices = m_Mesh.vertices;

            var oriColor = Gizmos.color;
            Gizmos.color = m_LineColor;
            for (int i = 0; i < normals.Length; i++)
            {
                var normalWS = transform.TransformVector(normals[i]);

                var from = transform.TransformVector(vertices[i]);
                var to = from + normalWS * m_LineLength;

                Gizmos.DrawLine(from, to);
            }
            Gizmos.color = oriColor;
        }
        else
        {
            var normals = m_Mesh.colors;
            var vertices = m_Mesh.vertices;

            var oriColor = Gizmos.color;
            Gizmos.color = m_LineColor;
            for (int i = 0; i < normals.Length; i++)
            {
                var normalWS = transform.TransformVector(new Vector3(normals[i].r, normals[i].g, normals[i].b));

                var from = transform.TransformVector(vertices[i]);
                var to = from + normalWS * m_LineLength;

                Gizmos.DrawLine(from, to);
            }
            Gizmos.color = oriColor;
        }
    }

    private Mesh GetMesh()
    {
        if (TryGetComponent(out MeshFilter meshFilter) && meshFilter.sharedMesh != null)
        {
            return meshFilter.sharedMesh;
        }
        else if (TryGetComponent(out SkinnedMeshRenderer skinnedMeshRenderer) && skinnedMeshRenderer.sharedMesh != null)
        {
            return skinnedMeshRenderer.sharedMesh;
        }

        return null;
    }

    private void Stop()
    {
        m_State = State.None;
    }

}
