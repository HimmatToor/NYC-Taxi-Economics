FROM apache/airflow:2.9.3-python3.11

USER airflow

COPY docker/requirements-airflow.txt /requirements-airflow.txt
RUN pip install --no-cache-dir -r /requirements-airflow.txt
