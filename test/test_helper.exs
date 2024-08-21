Mox.defmock(TransitData.MockDataLake, for: TransitData.DataLake)
Application.put_env(:transit_data, :data_lake_api, TransitData.MockDataLake)

ExUnit.start()
