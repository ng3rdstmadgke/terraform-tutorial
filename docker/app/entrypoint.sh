#!/bin/bash
uvicorn api.main:app --workers 2 --host 0.0.0.0 --port 80
