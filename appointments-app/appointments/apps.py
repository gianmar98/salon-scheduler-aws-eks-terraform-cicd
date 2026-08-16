"AppConfig settings"
from django.apps import AppConfig


class AppointmentsConfig(AppConfig):
    "AppConfig for Appointments"
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'appointments'
