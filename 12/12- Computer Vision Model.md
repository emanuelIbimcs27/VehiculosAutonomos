---
layout: default
title: Computer Vision Model
nav_order: 10
parent: CPS IoT Competition 2026
permalink: /Methodology/CVision_Model/
---

# Computer Vision Model

## Model loading & training

For this, we used a YOLO nano model which we trained using labeled images captured from the Qlabs environment. 

150 epochs
640 pixels image size
batch 32

![Load Model & Training](/assets/img/BloqueReadSensor.png)

When the training was finalized we got the following metrics:

![Training Performance](/assets/img/BloqueReadSensor.png)

This got us the following R values for each object

![R values](/assets/img/BloqueReadSensor.png)

## Model test

![Test image with bounding boxes for objects detected](/assets/img/BloqueReadSensor.png)

## Model implementation

