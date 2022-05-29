using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraMove : MonoBehaviour
{
    public float moveSpeed = 10,rotateSpeed;
    Vector3 mousePos;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        float h = Input.GetAxis("Horizontal");
        float v = Input.GetAxis("Vertical");
        float speed = moveSpeed;
        Vector3 move = new Vector3(h, 0, v);
        if (Input.GetKey(KeyCode.Q))
            move.y = -1;
        else if (Input.GetKey(KeyCode.E))
            move.y = 1;
        if (Input.GetKey(KeyCode.LeftShift))
            speed *= 2;

        Vector3 mouseDelta = Vector3.zero;
        if(Input.GetMouseButtonDown(1))
        {
            mousePos = Input.mousePosition;
        }
        else if(Input.GetMouseButton(1))
        {
            mouseDelta = Input.mousePosition - mousePos;
            mousePos = Input.mousePosition;
        }
        transform.RotateAround(transform.right, -rotateSpeed * Time.deltaTime * mouseDelta.y);
        transform.RotateAround(Vector3.up, rotateSpeed * Time.deltaTime * mouseDelta.x);
        transform.Translate(move.normalized * speed*Time.deltaTime, Space.Self);
    }
}
