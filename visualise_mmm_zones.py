import geopandas as gpd
import matplotlib.pyplot as plt

# Path to the GeoJSON file (update if needed)
GEOJSON_PATH = "InvoicingApplication/CopyableResources/mmm_sa1.geojson"

# Load the GeoJSON file
print(f"Loading GeoJSON from: {GEOJSON_PATH}")
gdf = gpd.read_file(GEOJSON_PATH)

# Plot all polygons, colored by MMM_CODE23
fig, ax = plt.subplots(figsize=(16, 16))
gdf.plot(ax=ax, column="MMM_CODE23", legend=True, cmap="tab20")
plt.title("MMM Zone Map (colored by MMM_CODE23)")
plt.axis('off')
plt.tight_layout()
plt.show()

# If you get an error about missing packages, install them with:
# pip install geopandas matplotlib 