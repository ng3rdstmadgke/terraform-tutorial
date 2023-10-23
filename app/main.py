
from fastapi import FastAPI
from typing import Union

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "root"}

@app.get("/fibonacci")
def fibonacci(cnt: int = 100):
    arr = [1, 1]
    for i in range(cnt):
        arr.append(arr[i] + arr[i + 1])
    return {"fibonacci": arr[len(arr) - 1]}

@app.get("/items/{item_id}")
def read_item(item_id: int, q: Union[str, None] = None):
    return {"item_id": item_id, "q": q}

