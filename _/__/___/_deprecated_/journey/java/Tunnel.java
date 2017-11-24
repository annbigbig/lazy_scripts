package com.kashu.demo;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.net.URL;
import java.net.URLConnection;
import java.nio.charset.Charset;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.json.JSONObject;

/*
 * http://stackoverflow.com/questions/2793150/using-java-net-urlconnection-to-fire-and-handle-http-requests
 * http://stackoverflow.com/questions/21404252/post-request-send-json-data-java-httpurlconnection
 */

public class Tunnel extends HttpServlet {
	
	protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
		doPost(request, response);
	}
	
	protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
		//System.out.println("doPost() has been called!");
		URLConnection connection = null;
		JSONObject json_in = null;
		StringBuilder sb = new StringBuilder();
		InputStreamReader in = null;
		OutputStreamWriter wr;
		String url = null;
		try{
			//url = request.getRequestURL().toString();
			url = "http://cdn3.crunchify.com/wp-content/uploads/code/json.sample.txt";
			System.out.println("request.getRequestURL()=" + url);
			json_in = parseJSONfromHttpRequest(request);
			connection = new URL(url).openConnection();
			connection.setDoOutput(true); // Triggers POST.
			connection.setRequestProperty("Accept-Charset", "UTF-8");
			connection.setRequestProperty("Content-Type", "application/json; charset=UTF-8");
			wr= new OutputStreamWriter(connection.getOutputStream());
			wr.write(json_in.toString());
			
			if (connection != null){
				connection.setReadTimeout(60 * 1000);
			}
			if (connection != null && connection.getInputStream() != null) {
				in = new InputStreamReader(connection.getInputStream(),"UTF-8");
				BufferedReader bufferedReader = new BufferedReader(in);
				if (bufferedReader != null) {
					int cp;
					while ((cp = bufferedReader.read()) != -1) {
						sb.append((char) cp);
					}
					bufferedReader.close();
				}
			}
			in.close();
			
		}catch(Exception e){
			e.printStackTrace();
		}
		response.setContentType("application/json; charset=UTF-8");
		//response.setContentType("application/json");
		PrintWriter out = response.getWriter();
		out.print(sb.toString());
		out.flush();
	}
	
	public JSONObject parseJSONfromHttpRequest(HttpServletRequest request) {
		JSONObject json = null;
		StringBuilder sb = new StringBuilder();
		try{
			request.setCharacterEncoding("UTF-8");
			BufferedReader reader = request.getReader();
		    String line;
		    while ((line = reader.readLine()) != null) {
		           sb.append(line).append('\n');
		    }
		    reader.close();
		    System.out.println(sb.toString());
		    json = new JSONObject(sb.toString());
		}catch(Exception e){
			e.printStackTrace();
		}
		return json;
	}
	
}
