from django.contrib import admin
from django.urls import path
from django.http import HttpResponse

def health(request):
    return HttpResponse("OK")

def index(request):
    return HttpResponse("Hello from Django on Cloud Run!")

urlpatterns = [
    path('admin/', admin.site.urls),
    path('health/', health),
    path('', index),
]
