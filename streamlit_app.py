!pip install joblib
import streamlit as st
import joblib
import pandas as pd


st.title('Predicting mower ownership')

income = st.number_input(label='Income',step=10)

lot_size = st.number_input(label='Lot Size',step=10)


df_pred = pd.DataFrame({'Income':[income],'Lot_Size':[lot_size]})

model = joblib.load('lda_model.pkl')
prediction = model.predict(df_pred)


if st.button(label='Predict'):
    prediction = prediction[0]
    st.write(prediction)
