# Nyquist demos (Chapter 9)

| Folder | What it shows | Main file |
| --- | --- | --- |
| `Contour Mapping` | draw a curve or contour on the s-plane and see its image through L(s); encirclements of −1 and the Nyquist criterion | `NYQ_Mapping_Demo.m` |
| `Bicycle` | rear-steered bicycle (Chapter 1 running example, Section 9.7): unstable and nonminimum phase; a speed slider moves the RHP zero, the lead C(s) = 9(s+3)/(s+20) keeps it up at 3 m/s | `BIKE_Realtime_Demo.m` |

Base MATLAB R2021a or newer; `BIKE_Realtime_Demo.m` uses the Control System Toolbox
to read C(s). The same demos run in the browser, without MATLAB:
`Web/nyquist/contour-mapping.html` and `Web/nyquist/bicycle.html` (button "Run in
the browser" on the course home page).
