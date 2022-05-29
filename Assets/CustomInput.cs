using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;

public class CustomInput : MonoBehaviour
{
    public static CustomInput Instance
    {
        get
        {
            if (_Instance == null)
            {
                _Instance = FindObjectOfType<CustomInput>();
            }
            return _Instance;
        }
    }
    static CustomInput _Instance;
    public Vector3 mousePosition { get; private set; }
    public Vector3 mouseDeltaPosition { get; private set; }
    float doubleClickTimeSpan = 0.25f;
    float doubleClickTimer = 0;
    public enum State { None, OnDown, Down, OnUp }
    public State currentState = State.None;
    public int clickTimes = 0;
    Vector3 prevMousePos;
    // Update is called once per frame
    void Update()
    {

        mousePosition = Vector3.zero;
        Vector3 mp = Vector3.zero;
        bool mouseDown =
#if UNITY_EDITOR || UNITY_STANDALONE
        Input.GetMouseButton(0);
        mp = Input.mousePosition;
#else
        Input.touchCount == 1;
        if(Input.touchCount >= 1)
           mp = Input.GetTouch(0).position;
#endif

        mousePosition = mp;

        mouseDeltaPosition = mousePosition - prevMousePos;
        prevMousePos = mousePosition;
        doubleClickTimer += Time.deltaTime;
        if (mouseDown && currentState == State.None)
        {
            currentState = State.OnDown;
            if (doubleClickTimer < doubleClickTimeSpan && clickTimes < 2)
            {
                clickTimes++;
            }
            else
            {
                clickTimes = 0;
            }
            doubleClickTimer = 0;
        }
        else if (mouseDown && currentState == State.OnDown)
        {
            currentState = State.Down;
        }
        else if (!mouseDown && currentState == State.Down)
        {
            currentState = State.OnUp;
        }
        else if (!mouseDown && currentState == State.OnUp)
        {
            currentState = State.None;
        }
        if (doubleClickTimer > doubleClickTimeSpan)
        {
            clickTimes = 0;
            doubleClickTimer = 0;
        }
    }

    public bool DoubleClick()
    {
        return clickTimes == 2;
    }
    public bool OnMouseDown()
    {
        return currentState == State.OnDown;
    }
    public bool OnMouse()
    {
        return currentState == State.Down;
    }
    public bool OverUI()
    {
#if UNITY_EDITOR || UNITY_STANDALONE
        return EventSystem.current.IsPointerOverGameObject();
#else
        if(Input.touchCount > 0)
        {
            return EventSystem.current.IsPointerOverGameObject(Input.GetTouch(0).fingerId);
        }
        else
        {
            return false;
        }
#endif
    }
}
