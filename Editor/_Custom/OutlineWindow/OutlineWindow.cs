using JetBrains.Annotations;
using PlasticGui.WorkspaceWindow.CodeReview;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Drawing.Drawing2D;
using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

public class OutlineWindow : EditorWindow
{
    
    [MenuItem("渲染管线工具/描边/平滑法线(顶点夹角加权-切线空间)")]
    public static void OpenWindow()
    {
        var window = EditorWindow.GetWindow<OutlineWindow>();
        window.titleContent = new GUIContent("选择需要平滑法线的Mesh");
        window.Show();
    }

    #region Style
    private class Style
    {
        public Type MeshType = typeof(Mesh);
        public GUIContent BtnLabel_WriteVertexColor_XY = new GUIContent("压缩法线进XY通道");
    }
    #endregion
    private Style m_GuiStyle = new Style();
    private Mesh m_TargetMesh;
    private bool m_WriteVertexColor_XY = true;

    private void OnGUI()
    {
        m_TargetMesh = EditorGUILayout.ObjectField(m_TargetMesh, m_GuiStyle.MeshType, false) as Mesh;
        m_WriteVertexColor_XY = EditorGUILayout.Toggle(m_GuiStyle.BtnLabel_WriteVertexColor_XY, m_WriteVertexColor_XY);
        if (GUILayout.Button("将平滑法线写入顶点色"))
        {
            if (m_TargetMesh == null)
                return;

            //if (!m_TargetMesh.isReadable)
            //{
            //    EditorUtility.DisplayDialog("提示","Mesh Read/Write Enabled is false","ok");
            //    return;
            //}

            var faceNormalMap = CreateFaceNormalMap(m_TargetMesh);
            var averageNormals = CalculateAverageNormals(faceNormalMap, m_TargetMesh);
            ObjectSpace2TangentSpace(averageNormals, m_TargetMesh);
            if (m_WriteVertexColor_XY)
            {
                for (int i = 0; i < averageNormals.Length; i++)
                {
                    averageNormals[i] = new Vector3(averageNormals[i].x, averageNormals[i].y, 1f);
                }
            }
            Color[] newColors = new Color[averageNormals.Length];
            for (int i = 0; i < newColors.Length; i++)
            {
                newColors[i] = new Color(averageNormals[i].x, averageNormals[i].y, averageNormals[i].z);
            }
            m_TargetMesh.SetColors(newColors);
            EditorUtility.SetDirty(m_TargetMesh);
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
        }
    }

    private static Dictionary<Vector3, List<Vector3>> CreateFaceNormalMap(Mesh mesh)
    {
        Dictionary<Vector3, List<Vector3>> faceNormalMap = new Dictionary<Vector3, List<Vector3>>();

        int[] triangles = mesh.triangles;
        int triLen = triangles.Length;
        Vector3[] vertices = mesh.vertices;
        //通过Span在栈上分配内存
        System.Span<Vector3> vPos = stackalloc Vector3[] { Vector3.zero, Vector3.zero, Vector3.zero };
        System.Span<int> nextId = stackalloc int[] { 1, 2, 0, 1 };

        for (int i = 0; i < triLen; i += 3)
        {
            int idx0 = triangles[i];
            int idx1 = triangles[i + 1];
            int idx2 = triangles[i + 2];

            vPos[0] = vertices[idx0];
            vPos[1] = vertices[idx1];
            vPos[2] = vertices[idx2];

            Vector3 lhs = vPos[1] - vPos[0];
            Vector3 rhs = vPos[2] - vPos[0];

            Vector3 fN = Vector3.Cross(lhs, rhs);
            fN /= fN.magnitude;//获得围绕顶点vertices[idx0]周围的三角面的法线

            for (int j = 0; j < 3; j++)
            {
                var edge0 = (vPos[nextId[j]] - vPos[j]);
                var edge1 = (vPos[nextId[j + 1]] - vPos[j]);

                edge0 /= edge0.magnitude;
                edge1 /= edge1.magnitude;

                var factor = Mathf.Acos(Vector3.Dot(edge0.normalized, edge1.normalized));//factor此时是三角面的夹角，作为权重
                var n = fN * factor;

                List<Vector3> normals;
                Vector3 position = vPos[j];

                if (!faceNormalMap.ContainsKey(position))
                {
                    normals = new List<Vector3> { n };
                    faceNormalMap.Add(position, normals);
                }
                else
                {
                    normals = faceNormalMap[position];
                    normals.Add(n);
                }
            }
        }
        return faceNormalMap;
    }

    private static Vector3[] CalculateAverageNormals(Dictionary<Vector3, List<Vector3>> faceNormalMap, Mesh mesh)
    {
        Vector3[] vertices = mesh.vertices;
        int vertLen = vertices.Length;
        Vector3[] averageNormals = new Vector3[vertLen];

        for (int i = 0; i < vertLen; i++)
        {
            List<Vector3> normals = faceNormalMap[vertices[i]];
            Vector3 n = normals[0];
            for (var j = 1; j < normals.Count; j++)
            {
                var normal = normals[j];
                n += normal;
            }
            averageNormals[i] = n.normalized;
        }
        return averageNormals;
    }

    private static void ObjectSpace2TangentSpace(Vector3[] normals, Mesh mesh)
    {
        for (int i = 0; i < normals.Length; i++)
        {
            Vector3 normalOS = normals[i];

            var tangent = mesh.tangents[i].normalized;
            var normal = mesh.normals[i].normalized;
            var bitangent = (Vector3.Cross(normal, tangent) * Mathf.Sign(tangent.w)).normalized;
            //不需要纠结TBN这个概念，只需要了解空间转换矩阵如何推导，网上对TBN的概念讲述是一团乱
            Matrix4x4 ts2os = new Matrix4x4(new Vector4(tangent.x, bitangent.x, normal.x, 0f),
                                             new Vector4(tangent.y, bitangent.y, normal.y, 0f),
                                             new Vector4(tangent.z, bitangent.z, normal.z, 0f),
                                             new Vector4(0f, 0f, 0f, 1f));
            var os2ts = ts2os.inverse;
            var normalTS = os2ts.MultiplyPoint(normalOS).normalized;//这里没有normalized的话，效果会差好大……
            normals[i] = normalTS;
        }
    }


}
