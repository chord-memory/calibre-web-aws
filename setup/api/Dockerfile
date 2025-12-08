FROM python:3.10-slim
WORKDIR /app
COPY api.py .
RUN pip install flask
EXPOSE 5000
CMD ["python", "api.py"]