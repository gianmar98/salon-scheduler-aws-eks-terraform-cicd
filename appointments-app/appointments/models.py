"Models for the hairdresser app"
from django.db import models

class Service(models.Model):
    "For services like haircut and color"
    service_id = models.AutoField(primary_key=True)
    service_name = models.CharField(max_length=100)
    description = models.TextField()
    price = models.DecimalField(max_digits=10, decimal_places=2)
    duration = models.IntegerField()

class Hairdresser(models.Model):
    "Hairdresser individuals"
    hairdresser_id = models.AutoField(primary_key=True)
    first_name = models.CharField(max_length=50)
    last_name = models.CharField(max_length=50)

class Appointment(models.Model):
    "Appointments for hairdressers"
    appointment_id = models.AutoField(primary_key=True)
    hairdresser = models.ForeignKey(Hairdresser, on_delete=models.CASCADE)
    service = models.ForeignKey(Service, on_delete=models.CASCADE)
    start_datetime = models.DateTimeField()
    end_datetime = models.DateTimeField()
    customer_contact = models.TextField()
