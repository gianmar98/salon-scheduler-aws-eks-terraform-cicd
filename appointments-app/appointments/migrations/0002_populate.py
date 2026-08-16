from django.db import migrations


def populate(apps, schema_editor):
    Data = apps.get_model("appointments", "Service")
    Data.objects.create(service_name="Haircut", description="Basic haircut service", price=50.00, duration=60)
    Data.objects.create(service_name="Hair Coloring", description="Complete hair coloring", price=75.00, duration=120)
    Data.objects.create(service_name="Shampoo and Style", description="Shampoo and styling service", price=35.00, duration=30)

    Data = apps.get_model("appointments", "Hairdresser")
    Data.objects.create(first_name="Hairdresser", last_name="One")
    Data.objects.create(first_name="Hairdresser", last_name="Two")

class Migration(migrations.Migration):

    dependencies = [
        ('appointments', '0001_initial'),
    ]

    operations = [
        migrations.RunPython(populate),
    ]
